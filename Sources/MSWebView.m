//
//  MSWebView.m
//  MSWebController
//
//  Created by Maxwell on 2017/5/7.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "MSWebView.h"
#import "MS_NJKWebViewProgress.h"
#import "MS_NJKWebViewProgressView.h"
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

static BOOL canUseWkWebView = NO;

@interface MSWebView () <UIWebViewDelegate, WKNavigationDelegate, WKUIDelegate, MS_NJKWebViewProgressDelegate>

@property (nonatomic, assign) CGFloat estimatedProgress;
@property (nonatomic, strong) NSURLRequest *originRequest;
@property (nonatomic, strong) NSURLRequest *currentRequest;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) MS_NJKWebViewProgress *njkWebViewProgress;
@property (nonatomic, strong) MS_NJKWebViewProgressView *njkWebProgressView;

@end

@implementation MSWebView

@synthesize usingUIWebView = _usingUIWebView;
@synthesize realWebView = _realWebView;
@synthesize scalesPageToFit = _scalesPageToFit;

+ (void)load {
    canUseWkWebView = (NSClassFromString(@"WKWebView") != nil);
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self _initMyself];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame usingUIWebView:NO];
}

- (instancetype)initWithFrame:(CGRect)frame usingUIWebView:(BOOL)usingUIWebView {
    self = [super initWithFrame:frame];
    if (self) {
        _usingUIWebView = usingUIWebView;
        [self _initMyself];
    }
    return self;
}

- (void)_initMyself {
    if (canUseWkWebView && self.usingUIWebView == NO) {
        [self initWKWebView];
        _usingUIWebView = NO;
    } else {
        [self initUIWebView];
        _usingUIWebView = YES;
    }
    [self.realWebView addObserver:self forKeyPath:@"loading" options:NSKeyValueObservingOptionNew context:nil];
    self.scalesPageToFit = YES;

    [self.realWebView setFrame:self.bounds];
    [self.realWebView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self addSubview:self.realWebView];

    self.njkWebProgressView = [[MS_NJKWebViewProgressView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 2)];
    self.njkWebProgressView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.njkWebProgressView];
    self.showProgressView = YES;
}

- (void)setDelegate:(id <MSWebViewDelegate>)delegate {
    _delegate = delegate;
    if (_usingUIWebView) {
        UIWebView *webView = self.realWebView;
        webView.delegate = nil;
        webView.delegate = self;
    } else {
        WKWebView *webView = self.realWebView;
        webView.UIDelegate = nil;
        webView.navigationDelegate = nil;
        webView.UIDelegate = self;
        webView.navigationDelegate = self;
    }
}

- (void)setEstimatedProgress:(CGFloat)estimatedProgress {
    _estimatedProgress = estimatedProgress;

    if (self.showProgressView) {
        [self.njkWebProgressView setProgress:estimatedProgress animated:YES];
    }
}

- (void)initWKWebView {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = [[WKUserContentController alloc] init];

    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.javaScriptCanOpenWindowsAutomatically = YES;
    configuration.preferences = preferences;

    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:configuration];
    webView.UIDelegate = self;
    webView.navigationDelegate = self;

    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;

    webView.allowsBackForwardNavigationGestures = YES;
    SEL linkPreviewSelector = NSSelectorFromString(@"setAllowsLinkPreview:");
    if ([webView respondsToSelector:linkPreviewSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [webView performSelector:linkPreviewSelector withObject:@(YES)];
#pragma clang diagnostic pop
    }

    [webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
    _realWebView = webView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.estimatedProgress = [change[NSKeyValueChangeNewKey] doubleValue];
    } else if ([keyPath isEqualToString:@"title"]) {
        self.title = change[NSKeyValueChangeNewKey];
    } else {
        [self willChangeValueForKey:keyPath];
        [self didChangeValueForKey:keyPath];
    }
}

- (void)initUIWebView {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.bounds];
    webView.backgroundColor = [UIColor clearColor];
    webView.allowsInlineMediaPlayback = YES;
    webView.mediaPlaybackRequiresUserAction = NO;

    webView.opaque = NO;
    for (UIView *subview in [webView.scrollView subviews]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            ((UIImageView *) subview).image = nil;
            subview.backgroundColor = [UIColor clearColor];
        }
    }

    self.njkWebViewProgress = [[MS_NJKWebViewProgress alloc] init];
    webView.delegate = _njkWebViewProgress;
    _njkWebViewProgress.webViewProxyDelegate = self;
    _njkWebViewProgress.progressDelegate = self;

    _realWebView = webView;
}

- (void)addScriptMessageHandler:(id <WKScriptMessageHandler>)scriptMessageHandler name:(NSString *)name {
    if (!_usingUIWebView) {
        WKWebViewConfiguration *configuration = [(WKWebView *) self.realWebView configuration];
        [configuration.userContentController addScriptMessageHandler:scriptMessageHandler name:name];
    }
}

- (JSContext *)jsContext {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    } else {
        return nil;
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    if (self.originRequest == nil) {
        self.originRequest = webView.request;
    }
    [self callback_webViewDidFinishLoad];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self callback_webViewDidStartLoad];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    BOOL resultBOOL = [self callback_webViewShouldStartLoadWithRequest:request navigationType:navigationType];
    return resultBOOL;
}

- (void)webViewProgress:(MS_NJKWebViewProgress *)webViewProgress updateProgress:(CGFloat)progress {
    self.estimatedProgress = progress;
}

#pragma mark - WKUIDelegate

- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WKFrameInfo *frameInfo = navigationAction.targetFrame;
    if (![frameInfo isMainFrame]) {
        if (navigationAction.request) {
            [webView loadRequest:navigationAction.request];
        }
    }
    return nil;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
- (void)webViewDidClose:(WKWebView *)webView {
}
#endif

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    // Get host name of url.
    NSString *host = webView.URL.host;
    // Init the alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host ?: NSLocalizedString(@"messages", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    // Init the cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:NULL];
    // Init the ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        completionHandler();
    }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    // Get the host name.
    NSString *host = webView.URL.host;
    // Initialize alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:host ?: NSLocalizedString(@"messages", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    // Initialize cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        completionHandler(NO);
    }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        completionHandler(YES);
    }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *__nullable result))completionHandler {
    // Get the host of url.
    NSString *host = webView.URL.host;
    // Initialize alert view controller.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:prompt ?: NSLocalizedString(@"messages", nil) message:host preferredStyle:UIAlertControllerStyleAlert];
    // Add text field.
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.placeholder = defaultText ?: NSLocalizedString(@"input", nil);
        textField.font = [UIFont systemFontOfSize:12];
    }];
    // Initialize cancel action.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", @"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        // Get inputed string.
        NSString *string = [alert.textFields firstObject].text;
        completionHandler(string ?: defaultText);
    }];
    // Initialize ok action.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"confirm", @"confirm") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
        // Get inputed string.
        NSString *string = [alert.textFields firstObject].text;
        completionHandler(string ?: defaultText);
    }];
    // Add actions.
    [alert addAction:cancelAction];
    [alert addAction:okAction];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    BOOL resultBOOL = [self callback_webViewShouldStartLoadWithRequest:navigationAction.request navigationType:navigationAction.navigationType];
    BOOL isLoadingDisableScheme = [self isLoadingWKWebViewDisableScheme:navigationAction.request.URL];

    // Disable all the '_blank' target in page's target.
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView evaluateJavaScript:@"var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','');}" completionHandler:nil];
    }

    // Resolve URL. Fixs the issue: https://github.com/devedbox/AXWebViewController/issues/7
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:webView.URL.absoluteString];
    if (!resultBOOL || isLoadingDisableScheme) {
        // For can deal something.
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if ([[NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'https://itunes.apple.com/cn/app/' OR SELF BEGINSWITH[cd] 'mailto:' OR SELF BEGINSWITH[cd] 'tel:' OR SELF BEGINSWITH[cd] 'telprompt:'"] evaluateWithObject:webView.URL.absoluteString]) {
        // For appstore.
        if ([[UIApplication sharedApplication] canOpenURL:webView.URL]) {
            if (UIDevice.currentDevice.systemVersion.floatValue >= 10.0) {
                [UIApplication.sharedApplication openURL:webView.URL options:@{} completionHandler:NULL];
            } else {
                [[UIApplication sharedApplication] openURL:webView.URL];
            }
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if (![[NSPredicate predicateWithFormat:@"SELF MATCHES[cd] 'https' OR SELF MATCHES[cd] 'http' OR SELF MATCHES[cd] 'file' OR SELF MATCHES[cd] 'about'"] evaluateWithObject:components.scheme]) {
        // For any other schema.
        if ([[UIApplication sharedApplication] canOpenURL:webView.URL]) {
            if (UIDevice.currentDevice.systemVersion.floatValue >= 10.0) {
                [UIApplication.sharedApplication openURL:webView.URL options:@{} completionHandler:NULL];
            } else {
                [[UIApplication sharedApplication] openURL:webView.URL];
            }
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        // Call the decision handler to allow to load web page.
        self.currentRequest = navigationAction.request;
        if (navigationAction.targetFrame == nil) {
            [webView loadRequest:navigationAction.request];
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self callback_webViewDidStartLoad];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self callback_webViewDidFinishLoad];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self callback_webViewDidFailLoadWithError:error];
}

#pragma mark - CALLBACK MSKWebView Delegate

- (void)callback_webViewDidFinishLoad {
    if (self.showProgressView) {
        [self.njkWebProgressView setProgress:1.0 animated:YES];
    }

    if ([self.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.delegate webViewDidFinishLoad:self];
    }
}

- (void)callback_webViewDidStartLoad {
    if (self.showProgressView) {
        [self.njkWebProgressView setProgress:0.1 animated:NO];
    }

    if ([self.delegate respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [self.delegate webViewDidStartLoad:self];
    }
}

- (void)callback_webViewDidFailLoadWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.delegate webView:self didFailLoadWithError:error];
    }
}

- (BOOL)callback_webViewShouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    BOOL resultBOOL = YES;
    if ([self.delegate respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        if (navigationType == -1) {
            navigationType = UIWebViewNavigationTypeOther;
        }
        resultBOOL = [self.delegate webView:self shouldStartLoadWithRequest:request navigationType:navigationType];
    }
    return resultBOOL;
}

#pragma mark - 基础方法

///判断当前加载的url是否是WKWebView不能打开的协议类型
- (BOOL)isLoadingWKWebViewDisableScheme:(NSURL *)url {
    BOOL retValue = NO;

    //判断是否正在加载WKWebview不能识别的协议类型：phone numbers, email address, maps, etc.
    if ([url.scheme isEqual:@"tel"]) {
        UIApplication *app = [UIApplication sharedApplication];
        if ([app canOpenURL:url]) {
            [app openURL:url];
            retValue = YES;
        }
    }

    return retValue;
}

- (UIScrollView *)scrollView {
    return [(id) self.realWebView scrollView];
}

- (id)loadRequest:(NSURLRequest *)request {
    self.originRequest = request;
    self.currentRequest = request;

    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView loadRequest:request];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView loadRequest:request];
    }
}

- (id)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView loadHTMLString:string baseURL:baseURL];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView loadHTMLString:string baseURL:baseURL];
    }
}

- (NSURLRequest *)currentRequest {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView request];
    } else {
        return _currentRequest;
    }
}

- (NSURL *)URL {
    if (_usingUIWebView) {
        return [(UIWebView *) self.realWebView request].URL;;
    } else {
        return [(WKWebView *) self.realWebView URL];
    }
}

- (BOOL)isLoading {
    return [self.realWebView isLoading];
}

- (BOOL)canGoBack {
    return [self.realWebView canGoBack];
}

- (BOOL)canGoForward {
    return [self.realWebView canGoForward];
}

- (id)goBack {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView goBack];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView goBack];
    }
}

- (id)goForward {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView goForward];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView goForward];
    }
}

- (id)reload {
    if (_usingUIWebView) {
        [(UIWebView *) self.realWebView reload];
        return nil;
    } else {
        return [(WKWebView *) self.realWebView reload];
    }
}

- (id)reloadFromOrigin {
    if (_usingUIWebView) {
        if (self.originRequest) {
            [self evaluateJavaScript:[NSString stringWithFormat:@"window.location.replace('%@')", self.originRequest.URL.absoluteString] completionHandler:nil];
        }
        return nil;
    } else {
        return [(WKWebView *) self.realWebView reloadFromOrigin];
    }
}

- (void)stopLoading {
    [self.realWebView stopLoading];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    if (_usingUIWebView) {
        NSString *result = [(UIWebView *) self.realWebView stringByEvaluatingJavaScriptFromString:javaScriptString];
        if (completionHandler) {
            completionHandler(result, nil);
        }
    } else {
        return [(WKWebView *) self.realWebView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
    }
}

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString {
    if (_usingUIWebView) {
        NSString *result = [(UIWebView *) self.realWebView stringByEvaluatingJavaScriptFromString:javaScriptString];
        return result;
    } else {
        __block NSString *result = nil;
        __block BOOL isExecuted = NO;
        [(WKWebView *) self.realWebView evaluateJavaScript:javaScriptString completionHandler:^(id obj, NSError *error) {
            result = obj;
            isExecuted = YES;
        }];

        while (isExecuted == NO) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        return result;
    }
}

- (void)setProgressColor:(UIColor *)progressColor {
    _progressColor = progressColor;
    [self.njkWebProgressView.progressBarView setBackgroundColor:progressColor];
}

- (void)setScalesPageToFit:(BOOL)scalesPageToFit {
    if (_usingUIWebView) {
        UIWebView *webView = _realWebView;
        webView.scalesPageToFit = scalesPageToFit;
    } else {
        if (_scalesPageToFit == scalesPageToFit) {
            return;
        }

        WKWebView *webView = _realWebView;

        NSString *jScript = [NSString stringWithFormat:@"var head = document.getElementsByTagName('head')[0];\
                             var hasViewPort = 0;\
                             var metas = head.getElementsByTagName('meta');\
                             for (var i = metas.length; i>=0 ; i--) {\
                             var m = metas[i];\
                             if (m.name == 'viewport') {\
                             hasViewPort = 1;\
                             break;\
                             }\
                             }; \
                             if(hasViewPort == 0) { \
                             var meta = document.createElement('meta'); \
                             meta.name = 'viewport'; \
                             meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'; \
                             head.appendChild(meta);\
                             }"];

        WKUserContentController *userContentController = webView.configuration.userContentController;
        NSMutableArray<WKUserScript *> *array = [userContentController.userScripts mutableCopy];
        WKUserScript *fitWKUScript = nil;
        for (WKUserScript *wkUScript in array) {
            if ([wkUScript.source isEqual:jScript]) {
                fitWKUScript = wkUScript;
                break;
            }
        }
        if (scalesPageToFit) {
            if (!fitWKUScript) {
                fitWKUScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
                [userContentController addUserScript:fitWKUScript];
            }
        } else {
            if (fitWKUScript) {
                [array removeObject:fitWKUScript];
            }
            /// 没法修改数组 只能移除全部 再重新添加
            [userContentController removeAllUserScripts];
            for (WKUserScript *wkUScript in array) {
                [userContentController addUserScript:wkUScript];
            }
        }
    }
    _scalesPageToFit = scalesPageToFit;
}

- (BOOL)scalesPageToFit {
    if (_usingUIWebView) {
        return [_realWebView scalesPageToFit];
    } else {
        return _scalesPageToFit;
    }
}

- (NSInteger)countOfHistory {
    if (_usingUIWebView) {
        UIWebView *webView = self.realWebView;

        int count = [[webView stringByEvaluatingJavaScriptFromString:@"window.history.length"] intValue];
        if (count) {
            return count;
        } else {
            return 1;
        }
    } else {
        WKWebView *webView = self.realWebView;
        return webView.backForwardList.backList.count;
    }
}

- (void)gobackWithStep:(NSInteger)step {
    if (self.canGoBack == NO)
        return;

    if (step > 0) {
        NSInteger historyCount = self.countOfHistory;
        if (step >= historyCount) {
            step = historyCount - 1;
        }

        if (_usingUIWebView) {
            UIWebView *webView = self.realWebView;
            [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.history.go(-%ld)", (long) step]];
        } else {
            WKWebView *webView = self.realWebView;
            WKBackForwardListItem *backItem = webView.backForwardList.backList[step];
            [webView goToBackForwardListItem:backItem];
        }
    } else {
        [self goBack];
    }
}

#pragma mark -  如果没有找到方法 去realWebView 中调用

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL hasResponds = [super respondsToSelector:aSelector];
    if (hasResponds == NO) {
        hasResponds = [self.delegate respondsToSelector:aSelector];
    }
    if (hasResponds == NO) {
        hasResponds = [self.realWebView respondsToSelector:aSelector];
    }
    return hasResponds;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *methodSign = [super methodSignatureForSelector:selector];
    if (methodSign == nil) {
        if ([self.realWebView respondsToSelector:selector]) {
            methodSign = [self.realWebView methodSignatureForSelector:selector];
        } else {
            methodSign = [(id) self.delegate methodSignatureForSelector:selector];
        }
    }
    return methodSign;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([self.realWebView respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.realWebView];
    } else {
        [invocation invokeWithTarget:self.delegate];
    }
}

#pragma mark - 清理

- (void)dealloc {
    if (_usingUIWebView) {
        UIWebView *webView = _realWebView;
        webView.delegate = nil;
    } else {
        WKWebView *webView = _realWebView;
        webView.UIDelegate = nil;
        webView.navigationDelegate = nil;

        [webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [webView removeObserver:self forKeyPath:@"title"];
    }
    [_realWebView removeObserver:self forKeyPath:@"loading"];
    [_realWebView scrollView].delegate = nil;
    [_realWebView stopLoading];
    [(UIWebView *) _realWebView loadHTMLString:@"" baseURL:nil];
    [_realWebView stopLoading];
    [_realWebView removeFromSuperview];
    _realWebView = nil;
}

@end
