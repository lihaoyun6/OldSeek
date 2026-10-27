#import "DSClient.h"
#import "cJSON.h"

#include <sys/socket.h>
#include <sys/select.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <time.h>

#include "mbedtls/ssl.h"
#include "mbedtls/net_sockets.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/sha256.h"
#include "mbedtls/base64.h"
#include "mbedtls/error.h"

static void ds_log(const char *fmt, ...) {
    FILE *f = fopen("/var/mobile/oldseek.log", "a");
    if (!f) return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fflush(f);
    fclose(f);
}

/* iPhone OS 3 has no glyphs for emoji or many pictographs, so they show up as
   empty boxes. Drop them (and the invisible modifiers that accompany them)
   before the text reaches the UI. */
static NSString *ds_sanitize_text(NSString *text) {
    NSUInteger length = [text length];
    if (length == 0) return text;

    unichar *buffer = (unichar *)malloc(length * sizeof(unichar));
    if (buffer == NULL) return text;
    [text getCharacters:buffer range:NSMakeRange(0, length)];

    NSUInteger out = 0;
    NSUInteger i;
    for (i = 0; i < length; i++) {
        unichar c = buffer[i];
        if (c >= 0xD800 && c <= 0xDFFF) continue;             /* surrogates */
        if (c >= 0xFE00 && c <= 0xFE0F) continue;             /* variation selectors */
        if (c == 0x200B || c == 0x200C || c == 0x200D) continue;
        if (c == 0x20E3) continue;                            /* keycap combiner */
        if (c == 0xFFFD) continue;                            /* replacement char */
        if (c >= 0x2300 && c <= 0x23FF) continue;             /* technical symbols */
        if (c >= 0x25A0 && c <= 0x25FF) continue;             /* geometric shapes */
        if (c >= 0x2600 && c <= 0x27BF) continue;             /* symbols / dingbats */
        if (c >= 0x2B00 && c <= 0x2BFF) continue;             /* extra arrows / shapes */
        buffer[out++] = c;
    }

    NSString *result = [NSString stringWithCharacters:buffer length:out];
    free(buffer);
    return result;
}

static NSString *ds_base64_file(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSUInteger length = [data length];
    if (length == 0) return nil;

    size_t outLength = ((length + 2) / 3) * 4 + 1;
    unsigned char *buffer = (unsigned char *)malloc(outLength);
    if (buffer == NULL) return nil;

    size_t written = 0;
    int ret = mbedtls_base64_encode(buffer, outLength, &written,
                                    [data bytes], length);
    if (ret != 0) {
        free(buffer);
        return nil;
    }
    buffer[written] = '\0';

    NSString *result = [NSString stringWithCString:(const char *)buffer
                                          encoding:NSASCIIStringEncoding];
    free(buffer);
    return result;
}

static int ds_connect(const char *host, const char *port, int timeout_ms) {
    struct addrinfo hints, *res = NULL, *p;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    if (getaddrinfo(host, port, &hints, &res) != 0) return -1;

    int fd = -1;
    for (p = res; p != NULL; p = p->ai_next) {
        fd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (fd < 0) continue;

        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

        int r = connect(fd, p->ai_addr, p->ai_addrlen);
        if (r < 0 && errno == EINPROGRESS) {
            fd_set wf;
            FD_ZERO(&wf);
            FD_SET(fd, &wf);
            struct timeval tv;
            tv.tv_sec = timeout_ms / 1000;
            tv.tv_usec = (timeout_ms % 1000) * 1000;
            r = select(fd + 1, NULL, &wf, NULL, &tv);
            if (r > 0) {
                int err = 0;
                socklen_t elen = sizeof(err);
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &elen);
                r = (err == 0) ? 0 : -1;
            } else {
                r = -1;
            }
        } else if (r == 0) {
            r = 0;
        }

        if (r == 0) {
            fcntl(fd, F_SETFL, flags);
            break;
        }
        close(fd);
        fd = -1;
    }

    freeaddrinfo(res);
    return fd;
}

static int ds_bio_send(void *ctx, const unsigned char *buf, size_t len) {
    int fd = *(int *)ctx;
    size_t off = 0;
    while (off < len) {
        ssize_t n = send(fd, buf + off, len - off, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return MBEDTLS_ERR_NET_SEND_FAILED;
        }
        if (n == 0) return MBEDTLS_ERR_NET_CONN_RESET;
        off += (size_t)n;
    }
    return (int)off;
}

static int ds_bio_recv(void *ctx, unsigned char *buf, size_t len) {
    int fd = *(int *)ctx;
    for (;;) {
        ssize_t n = recv(fd, buf, len, 0);
        if (n < 0) {
            if (errno == EINTR) continue;
            return MBEDTLS_ERR_NET_RECV_FAILED;
        }
        return (int)n;
    }
}

static long ds_find(const unsigned char *hay, size_t n, const char *needle, size_t m) {
    if (n < m) return -1;
    size_t i;
    for (i = 0; i + m <= n; i++) {
        if (hay[i] == (unsigned char)needle[0] && memcmp(hay + i, needle, m) == 0) {
            return (long)i;
        }
    }
    return -1;
}

static int ds_parse_status(NSString *head) {
    NSRange sp = [head rangeOfString:@" "];
    if (sp.location == NSNotFound) return 0;
    NSString *rest = [head substringFromIndex:sp.location + 1];
    return [rest intValue];
}

typedef struct {
    int state;      /* 0 = chunk size, 1 = data, 2 = CRLF, 3 = done */
    long remaining;
    char sizebuf[32];
    int sizelen;
} ds_chunk;

static void ds_chunk_feed(ds_chunk *c, const unsigned char *p, size_t n, NSMutableData *out) {
    size_t i = 0;
    while (i < n && c->state != 3) {
        if (c->state == 0) {
            unsigned char ch = p[i++];
            if (ch == '\n') {
                c->sizebuf[c->sizelen] = 0;
                long v = strtol(c->sizebuf, NULL, 16);
                c->sizelen = 0;
                if (v <= 0) {
                    c->state = 3;
                } else {
                    c->remaining = v;
                    c->state = 1;
                }
            } else if (ch != '\r' && c->sizelen < 30) {
                c->sizebuf[c->sizelen++] = (char)ch;
            }
        } else if (c->state == 1) {
            size_t take = n - i;
            if ((long)take > c->remaining) take = (size_t)c->remaining;
            [out appendBytes:p + i length:take];
            i += take;
            c->remaining -= (long)take;
            if (c->remaining == 0) c->state = 2;
        } else {
            unsigned char ch = p[i++];
            if (ch == '\n') c->state = 0;
        }
    }
}

@implementation DSClient

@synthesize delegate = _delegate;

- (id)init {
    if ((self = [super init])) {
        _lock = [[NSLock alloc] init];
        _sock = -1;
        _cancelled = NO;
    }
    return self;
}

- (void)sendMessages:(NSArray *)messages model:(NSString *)model apiKey:(NSString *)apiKey {
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "model", [model UTF8String]);
    cJSON_AddBoolToObject(root, "stream", 1);

    cJSON *array = cJSON_AddArrayToObject(root, "messages");
    NSDictionary *m;
    for (m in messages) {
        cJSON *o = cJSON_CreateObject();
        cJSON_AddStringToObject(o, "role", [[m objectForKey:@"role"] UTF8String]);

        NSString *text = [m objectForKey:@"text"];
        NSArray *images = [m objectForKey:@"images"];
        if ([images count] > 0) {
            cJSON *content = cJSON_CreateArray();

            if ([text length] > 0) {
                cJSON *textPart = cJSON_CreateObject();
                cJSON_AddStringToObject(textPart, "type", "text");
                cJSON_AddStringToObject(textPart, "text", [text UTF8String]);
                cJSON_AddItemToArray(content, textPart);
            }

            NSString *path;
            for (path in images) {
                NSString *base64 = ds_base64_file(path);
                if (base64 == nil) continue;
                NSString *dataURL = [NSString stringWithFormat:
                                     @"data:image/jpeg;base64,%@", base64];
                cJSON *imagePart = cJSON_CreateObject();
                cJSON_AddStringToObject(imagePart, "type", "image_url");
                cJSON *imageURL = cJSON_AddObjectToObject(imagePart, "image_url");
                cJSON_AddStringToObject(imageURL, "url", [dataURL UTF8String]);
                cJSON_AddItemToArray(content, imagePart);
            }

            if (cJSON_GetArraySize(content) == 0) {
                cJSON_Delete(content);
                cJSON_AddStringToObject(o, "content",
                                        [(text ? text : @"") UTF8String]);
            } else {
                cJSON_AddItemToObject(o, "content", content);
            }
        } else {
            cJSON_AddStringToObject(o, "content",
                                    [(text ? text : @"") UTF8String]);
        }
        cJSON_AddItemToArray(array, o);
    }

    char *printed = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!printed) return;

    NSData *body = [NSData dataWithBytes:printed length:strlen(printed)];
    free(printed);

    NSDictionary *req = [NSDictionary dictionaryWithObjectsAndKeys:
                         body, @"body",
                         (apiKey ? apiKey : @""), @"key",
                         nil];
    [NSThread detachNewThreadSelector:@selector(run:) toTarget:self withObject:req];
}

- (void)cancel {
    _cancelled = YES;
    [_lock lock];
    if (_sock >= 0) shutdown(_sock, SHUT_RDWR);
    [_lock unlock];
}

- (void)run:(NSDictionary *)req {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *error = [self performRequest:req];
    if (_cancelled) error = nil;

    if (error) {
        ds_log("request failed: %s", [error UTF8String]);
        [(NSObject *)self.delegate performSelectorOnMainThread:@selector(dsClientDidFail:)
                                        withObject:error
                                     waitUntilDone:NO];
    } else {
        [(NSObject *)self.delegate performSelectorOnMainThread:@selector(dsClientDidFinish)
                                        withObject:nil
                                     waitUntilDone:NO];
    }
    [pool release];
}

- (NSString *)performRequest:(NSDictionary *)req {
    NSData *body = [req objectForKey:@"body"];
    NSString *key = [req objectForKey:@"key"];

    NSString *result = nil;
    NSMutableData *hdr = nil;
    NSMutableData *lineBuf = nil;
    NSMutableData *errBody = nil;
    NSMutableData *decoded = nil;

    int fd = ds_connect("api.deepseek.com", "443", 10000);
    if (fd < 0) {
        ds_log("connect failed");
        return NSLocalizedString(@"Unable to connect to api.deepseek.com", nil);
    }

    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
    struct timeval tv;
    tv.tv_sec = 60;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    tv.tv_sec = 10;
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    [_lock lock];
    _sock = fd;
    [_lock unlock];

    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context drbg;
    mbedtls_x509_crt ca;
    BOOL verifying = NO;
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_entropy_init(&entropy);
    mbedtls_ctr_drbg_init(&drbg);
    mbedtls_x509_crt_init(&ca);

    int ret;
    static const char *pers = "oldseek";

    ret = mbedtls_ctr_drbg_seed(&drbg, mbedtls_entropy_func, &entropy,
                                (const unsigned char *)pers, strlen(pers));
    if (ret != 0) {
        result = [NSString stringWithFormat:NSLocalizedString(@"Random number initialization failed (%d)", nil), ret];
        goto done;
    }

    ret = mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                      MBEDTLS_SSL_TRANSPORT_STREAM,
                                      MBEDTLS_SSL_PRESET_DEFAULT);
    if (ret != 0) {
        result = [NSString stringWithFormat:NSLocalizedString(@"TLS configuration failed (%d)", nil), ret];
        goto done;
    }

    /* The device clock is sometimes stuck in 2000; certificate validity
       checks only make sense when it is actually set. */
    NSString *caPath = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
    if (time(NULL) > 1577836800 && caPath != nil &&
        mbedtls_x509_crt_parse_file(&ca, [caPath fileSystemRepresentation]) == 0) {
        mbedtls_ssl_conf_ca_chain(&conf, &ca, NULL);
        mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_REQUIRED);
        verifying = YES;
    } else {
        mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_NONE);
    }
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &drbg);
    mbedtls_ssl_conf_min_version(&conf, MBEDTLS_SSL_MAJOR_VERSION_3,
                                 MBEDTLS_SSL_MINOR_VERSION_3);

    ret = mbedtls_ssl_setup(&ssl, &conf);
    if (ret != 0) {
        result = [NSString stringWithFormat:NSLocalizedString(@"TLS initialization failed (%d)", nil), ret];
        goto done;
    }
    mbedtls_ssl_set_hostname(&ssl, "api.deepseek.com");
    mbedtls_ssl_set_bio(&ssl, &fd, ds_bio_send, ds_bio_recv, NULL);

    ret = mbedtls_ssl_handshake(&ssl);
    if (ret != 0) {
        char msg[128];
        mbedtls_strerror(ret, msg, sizeof(msg));
        ds_log("handshake failed: %s (%d)", msg, ret);
        result = [NSString stringWithFormat:NSLocalizedString(@"TLS handshake failed: %s", nil), msg];
        goto done;
    }

    /* When chain validation is not possible, remember the leaf certificate
       fingerprint instead (trust on first use). */
    if (!verifying) {
        const mbedtls_x509_crt *crt = mbedtls_ssl_get_peer_cert(&ssl);
        if (crt != NULL && crt->raw.p != NULL && crt->raw.len > 0) {
            unsigned char hash[32];
            mbedtls_sha256_ret(crt->raw.p, crt->raw.len, hash, 0);
            NSMutableString *fp = [NSMutableString string];
            int i;
            for (i = 0; i < 32; i++) [fp appendFormat:@"%02x", hash[i]];

            NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
            NSString *saved = [defs stringForKey:@"cert_sha256"];
            if (saved == nil) {
                [defs setObject:fp forKey:@"cert_sha256"];
                [defs synchronize];
            } else if (![saved isEqualToString:fp]) {
                result = NSLocalizedString(@"Server certificate fingerprint mismatch", nil);
                goto done;
            }
        }
    }

    {
        NSString *head = [NSString stringWithFormat:
            @"POST /chat/completions HTTP/1.1\r\n"
             "Host: api.deepseek.com\r\n"
             "Authorization: Bearer %@\r\n"
             "Content-Type: application/json\r\n"
             "Accept: text/event-stream\r\n"
             "Connection: close\r\n"
             "Content-Length: %lu\r\n\r\n",
            key, (unsigned long)[body length]];

        NSMutableData *reqData = [NSMutableData data];
        [reqData appendData:[head dataUsingEncoding:NSUTF8StringEncoding]];
        [reqData appendData:body];

        const unsigned char *p = [reqData bytes];
        size_t left = [reqData length];
        while (left > 0 && !_cancelled) {
            int n = mbedtls_ssl_write(&ssl, p, left);
            if (n <= 0) {
                result = [NSString stringWithFormat:NSLocalizedString(@"Failed to send request (%d)", nil), n];
                goto done;
            }
            p += n;
            left -= (size_t)n;
        }
    }

    hdr = [[NSMutableData alloc] init];
    lineBuf = [[NSMutableData alloc] init];
    errBody = [[NSMutableData alloc] init];
    decoded = [[NSMutableData alloc] init];

    ds_chunk chunk;
    memset(&chunk, 0, sizeof(chunk));

    BOOL headerDone = NO;
    BOOL chunked = NO;
    BOOL isError = NO;
    BOOL finished = NO;
    int status = 0;

    unsigned char buf[4096];
    while (!finished && !_cancelled) {
        int n = mbedtls_ssl_read(&ssl, buf, sizeof(buf));
        if (n == MBEDTLS_ERR_SSL_WANT_READ || n == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        if (n == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) break;
        if (n < 0) {
            char msg[128];
            mbedtls_strerror(n, msg, sizeof(msg));
            ds_log("read failed: %s (%d)", msg, n);
            result = [NSString stringWithFormat:NSLocalizedString(@"Failed to read response: %s", nil), msg];
            break;
        }
        if (n == 0) break;

        if (!headerDone) {
            [hdr appendBytes:buf length:n];
            long he = ds_find([hdr bytes], [hdr length], "\r\n\r\n", 4);
            if (he < 0) continue;

            NSString *headStr = [[NSString alloc] initWithBytes:[hdr bytes]
                                                         length:he
                                                       encoding:NSUTF8StringEncoding];
            if (headStr) {
                status = ds_parse_status(headStr);
                chunked = [[headStr lowercaseString] rangeOfString:@"transfer-encoding: chunked"].location != NSNotFound;
                [headStr release];
            }
            isError = (status != 200);
            headerDone = YES;

            NSUInteger off = (NSUInteger)he + 4;
            if (off < [hdr length]) {
                const unsigned char *bp = (const unsigned char *)[hdr bytes] + off;
                size_t bl = [hdr length] - off;
                if (chunked) ds_chunk_feed(&chunk, bp, bl, decoded);
                else [decoded appendBytes:bp length:bl];
            }
            [hdr setLength:0];
        } else {
            if (chunked) ds_chunk_feed(&chunk, buf, n, decoded);
            else [decoded appendBytes:buf length:n];
        }

        if ([decoded length] > 0) {
            if (isError) {
                [errBody appendData:decoded];
            } else {
                finished = ![self processBody:[decoded bytes]
                                       length:[decoded length]
                                      lineBuf:lineBuf];
            }
            [decoded setLength:0];
        }

        if (chunked && chunk.state == 3) break;
    }

    if (_cancelled) {
        result = nil;
    } else if (!headerDone) {
        result = NSLocalizedString(@"The server returned no response", nil);
    } else if (isError) {
        NSString *text = [[NSString alloc] initWithData:errBody encoding:NSUTF8StringEncoding];
        NSString *detail = nil;
        if (text) {
            cJSON *root = cJSON_Parse([text UTF8String]);
            if (root) {
                cJSON *err = cJSON_GetObjectItem(root, "error");
                cJSON *msg = cJSON_GetObjectItem(err, "message");
                if (msg && msg->valuestring) detail = [NSString stringWithUTF8String:msg->valuestring];
                cJSON_Delete(root);
            }
            [text release];
        }
        if (detail) result = [NSString stringWithFormat:@"HTTP %d: %@", status, detail];
        else result = [NSString stringWithFormat:@"HTTP %d", status];
    }

done:
    [_lock lock];
    _sock = -1;
    [_lock unlock];
    if (ssl.conf != NULL) mbedtls_ssl_close_notify(&ssl);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&drbg);
    mbedtls_entropy_free(&entropy);
    mbedtls_x509_crt_free(&ca);
    close(fd);

    [hdr release];
    [lineBuf release];
    [errBody release];
    [decoded release];
    return result;
}

- (BOOL)processBody:(const unsigned char *)bytes
             length:(size_t)length
            lineBuf:(NSMutableData *)lineBuf {
    [lineBuf appendBytes:bytes length:length];

    const unsigned char *b = (const unsigned char *)[lineBuf bytes];
    size_t total = [lineBuf length];
    size_t start = 0;
    size_t i;

    for (i = 0; i < total; i++) {
        if (b[i] != '\n') continue;

        size_t len = i - start;
        if (len > 0 && b[start + len - 1] == '\r') len--;

        NSString *line = [[NSString alloc] initWithBytes:b + start
                                                  length:len
                                                encoding:NSUTF8StringEncoding];
        BOOL keepGoing = YES;
        if (line) keepGoing = [self handleLine:line];
        [line release];

        start = i + 1;
        if (!keepGoing) {
            [lineBuf setLength:0];
            return NO;
        }
    }

    if (start > 0) {
        [lineBuf replaceBytesInRange:NSMakeRange(0, start) withBytes:NULL length:0];
    }
    return YES;
}

- (BOOL)handleLine:(NSString *)line {
    if (![line hasPrefix:@"data:"]) return YES;

    NSString *payload = [line substringFromIndex:5];
    if ([payload hasPrefix:@" "]) payload = [payload substringFromIndex:1];
    if ([payload isEqualToString:@"[DONE]"]) return NO;

    cJSON *root = cJSON_Parse([payload UTF8String]);
    if (!root) return YES;

    cJSON *choices = cJSON_GetObjectItem(root, "choices");
    cJSON *choice = cJSON_GetArrayItem(choices, 0);
    cJSON *delta = cJSON_GetObjectItem(choice, "delta");
    cJSON *content = cJSON_GetObjectItem(delta, "content");

    if (content != NULL && content->type == cJSON_String && content->valuestring != NULL) {
        NSString *text = [NSString stringWithUTF8String:content->valuestring];
        if ([text length] > 0) {
            text = ds_sanitize_text(text);
        }
        if ([text length] > 0) {
            [(NSObject *)self.delegate performSelectorOnMainThread:@selector(dsClientDidReceiveDelta:)
                                            withObject:text
                                         waitUntilDone:NO];
        }
    }

    cJSON_Delete(root);
    return YES;
}

- (void)dealloc {
    [_lock release];
    [super dealloc];
}

@end
