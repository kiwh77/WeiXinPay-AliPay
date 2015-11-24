//
//  PayManager.m
//  PayDemo
//
//  Created by 吴浩 on 15/11/20.
//  Copyright © 2015年 kwih77. All rights reserved.
//

#import "WHPayManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "ifaddrs.h"
#import <arpa/inet.h>
#import "XMLDictionary.h"

#import "Order.h"
#import "DataSigner.h"

#define WXPrepayReturn_code @"return_code"
#define WXPrepayResult_code @"result_code"
#define SUCCESS @"SUCCESS"
#define FAIL @"FAIL"

@interface WHPayManager()
@property (nonatomic, copy) PayCompletionCallBack WXCompletion;

@end

@implementation WHPayManager
@synthesize payInfo;

+(instancetype)simpleInstance
{
    static WHPayManager * instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WHPayManager alloc] init];
        instance.payInfo = [instance getPayInfo];
    });
    return instance;
}

-(void)AlipayWithParams:(NSDictionary *)params completion:(PayCompletionCallBack)completion
{
    //添加和检查各项参数
    NSArray * keys = [params allKeys];
    if (![keys containsObject:ORDER_ID] ||
        ![keys containsObject:PRODUCTNAME] ||
        ![keys containsObject:DESCRIPTION] ||
        ![keys containsObject:AMOUNT]) {
        completion(NO,3000,@"必要产品信息缺失");
        return;
    }
    
    NSMutableDictionary * allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [[payInfo objectForKey:ALIPAYINFO] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (key && obj && ![(NSString*)obj isEqualToString:@""]) {
            [allParams setObject:obj forKey:key];
        }
    }];
    Order * order = [[Order alloc] initWithParams:allParams];
    NSString * orderDesc = [order description];
    //获取私钥并签名
    id<DataSigner> singer = CreateRSADataSigner([allParams objectForKey:ALI_PRIVATE_KEY]);
    NSString * singerString = [singer signString:orderDesc];
    NSString * orderString = nil;
    if (singerString) {
        //按规定拼装字符串
        orderString = [NSString stringWithFormat:@"%@&sign=\"%@\"&sign_type=\"%@\"",orderDesc,singerString,@"RSA"];
        [[AlipaySDK defaultService] payOrder:orderString fromScheme:[allParams objectForKey:APPSCHEME] callback:^(NSDictionary *resultDic) {
            NSString * payCode = [resultDic objectForKey:@"resultStatus"];
            switch (payCode.integerValue) {
                case 9000:completion(YES,payCode.integerValue,@"支付成功!");
                    break;
                case 8000:completion(NO,payCode.integerValue,@"正在处理中...");
                    break;
                case 6001:completion(NO,payCode.integerValue,@"用户取消支付!");
                    break;
                case 6002:completion(NO,payCode.integerValue,@"网络连接错误!");
                    break;
                case 4000:completion(NO,payCode.integerValue,@"支付失败!");
                    break;
                default:break;
            }
        }];
    }
}

//调用统一下单api
-(void)WeiXinPrePayWithParams:(NSDictionary *)params completion:(PayCompletionCallBack)completion
{
    //检测是否有必要参数
    NSArray * keys = [params allKeys];
    if (![keys containsObject:BOBY] || ![keys containsObject:OUT_TRADE_NO] || ![keys containsObject:TOTAL_FEE]) {
        completion(NO,WXPrepayParamsLosed,@"必要产品参数不全");
        return;
    }
    NSDictionary * wxPayInfo = [payInfo objectForKey:WXPAYINFO];
    
    NSMutableDictionary * allParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [wxPayInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (key && obj && ![(NSString*)obj isEqualToString:@""]) {
            [allParams setObject:obj forKey:key];
        }
    }];
    
    //添加随机字符串
    [allParams setObject:randomString(30) forKey:NONCE_STR];
    //添加IP
    [allParams setObject:[self getIPAddress] forKey:SPBILL_CREATE_IP];
    //算出签名后添加
    [allParams setObject:[self createMd5Sign:allParams] forKey:SIGN];
    
    //转换成xml格式的data
    NSData * xmlData = [self XMLDataByDictionary:allParams];
    //调用统一下单api
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:PrepayURL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"text/XML" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:xmlData];
    
    NSURLSession * sesssion = [NSURLSession sharedSession];
    NSURLSessionDataTask * sessionDataTask =  [sesssion dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            completion(NO,WXPrepayApiFailed,@"调用微信统一下单Api失败!");
        }else{
            //此处解析工具为 https://github.com/nicklockwood/XMLDictionary
            NSDictionary * responseResult = [NSDictionary dictionaryWithXMLData:data];
            NSString * return_code = [responseResult objectForKey:WXPrepayReturn_code];
            NSString * result_code = [responseResult objectForKey:WXPrepayResult_code];
            if ( [return_code isEqualToString:SUCCESS] &&  [result_code isEqualToString:SUCCESS])
            {
                //验证业务处理状态
                [self WeiXinPayWithParams:@{PREPAYID:[responseResult objectForKey:@"prepay_id"]} completion:completion];
            }else{
                completion(NO,WXPrepayReturnError,[responseResult objectForKey:@"return_msg"]);
            }
        }
    }];
    
    [sessionDataTask resume];
}

-(void)WeiXinPayWithParams:(NSDictionary *)params completion:(PayCompletionCallBack)completion
{
    
    if (![params.allKeys containsObject:@"prepayid"]) {
        completion(NO,WXPayPrepayIdLosed,@"预付款单号缺失");
        return;
    }
    PayReq * req = [[PayReq alloc] init];
    req.prepayId = [params objectForKey:PREPAYID];
    req.partnerId = [[payInfo objectForKey:WXPAYINFO] objectForKey:MCH_ID];
    req.package = @"Sign=WXPay";
    req.timeStamp = [[NSDate date] timeIntervalSince1970];
    req.nonceStr = randomString(30);
    
    NSDictionary * signParams = @{PARTNER_ID:req.partnerId,
                                  PREPAYID:req.prepayId,
                                  PACKAGE:req.package,
                                  TIMESTAMP:@(req.timeStamp),
                                  @"noncestr":req.nonceStr,
                                  APPID_WX:[[payInfo objectForKey:WXPAYINFO] objectForKey:APPID_WX]};
    
    req.sign = [self createMd5Sign:signParams];
    [WXApi sendReq:req] ? _WXCompletion = completion : completion(NO,WXPayRequestFailed,@"微信支付请求失败!");
}

-(void)handleWXResult:(BaseResp*)resp
{
    /*
    0	成功	展示成功页面
    -1	错误	可能的原因：签名错误、未注册APPID、项目设置APPID不正确、注册的APPID与设置的不匹配、其他异常等。
    -2	用户取消	无需处理。发生场景：用户不支付了，点击取消，返回APP。
     */
    if (_WXCompletion) {
        switch (resp.errCode) {
            case 0:_WXCompletion(YES,WXPayResponseSuccess,@"支付成功!");break;
            case -1:_WXCompletion(NO,WXPayResponseError,@"签名错误!");
                break;
            case -2:_WXCompletion(NO,WXPayResponseCancel,@"用户取消");
            default: break;
        }
    }
}


#pragma mark - Private method

//取得PayInfo.plist中信息
-(NSDictionary*)getPayInfo
{
    NSString * infoPath = [[NSBundle mainBundle] pathForResource:@"PayInfo" ofType:@"plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPath]) {
        return [NSDictionary dictionaryWithContentsOfFile:infoPath];
    }
    assert("PayInfo.plist 文件不存在!");
    return nil;
}

//随机字符串函数
NSString * randomString(int length){
    char * name = "abcdefghijklmnopqrstuvwxyzABCDEFGHJIKLMNOPQRSTUVW0123456789";
    NSMutableString * ms = [NSMutableString  string];
    int flag = 0;
    while (flag < length) {
        int index = rand()%strlen(name);
        [ms appendFormat:@"%c",name[index]];
        flag++;
    }
    return ms;
}

//创建MD5签名
-(NSString*) createMd5Sign:(NSDictionary*)dict
{
    NSMutableString *contentString  =[NSMutableString string];
    NSArray *keys = [dict allKeys];
    //按字母顺序排序
    NSArray *sortedArray = [keys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    
    //拼接字符串
    for (NSString *categoryId in sortedArray) {
        if (![categoryId isEqualToString:@"sign"]
            && ![categoryId isEqualToString:@"key"]
            ){
            [contentString appendFormat:@"%@=%@&", categoryId, [dict objectForKey:categoryId]];
        }
        
    }
    //添加key字段
    [contentString appendFormat:@"key=%@", [[payInfo objectForKey:WXPAYINFO] objectForKey:KEY_WX]];
    //得到MD5 sign签名
    NSString *md5Sign =[self md5HexDigest:contentString];
    
    return md5Sign;
}

//MD5
- (NSString *)md5HexDigest:(NSString*)input
{
    const char* str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

//获取自身ip
- (NSString *)getIPAddress
{
    NSString *address = @"192.168.1.1";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en1"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

//拼装XMLData
-(NSData*)XMLDataByDictionary:(NSDictionary*)params
{
    __block NSString  * result = @"<xml>";
    [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key isEqualToString:KEY_WX]) {
            result = [NSString stringWithFormat:@"%@<%@>%@</%@>",result,key,obj,key];
        }
    }];
    result = [result stringByAppendingString:@"</xml>"];
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}



@end
