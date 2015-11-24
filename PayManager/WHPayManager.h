//
//  PayManager.h
//  PayDemo
//
//  Created by 吴浩 on 15/11/20.
//  Copyright © 2015年 kwih77. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WXApiObject.h"
#import "WXApi.h"
#import <AlipaySDK/AlipaySDK.h>

#define WXPAYINFO @"WXPay"
#define ALIPAYINFO @"Alipay"
//Ali
#define APPID_ALI @"appID"
#define SELLER @"seller"
#define PARTNER @"partner"
#define APPSCHEME @"appScheme"
#define SERVICE @"service"
#define NOTIFYURL_ALI @"notifyURL"
#define PAYMENTTYPE @"paymentType"
#define INPUTCHARSET @"inputCharset"
#define ITBPAY @"itBPay"
#define SHOWURL @"showUrl"

#define ORDER_ID @"tradeNO"
#define PRODUCTNAME @"productName"
#define DESCRIPTION @"productDescription"
#define AMOUNT @"amount"
#define ALI_PRIVATE_KEY @"privateKey"
//WX
#define APPID_WX @"appid"
#define MCH_ID @"mch_id"
#define NOTIFY_URL_WX @"notify_url"
#define KEY_WX @"key"
#define TRADE_TYPE @"trade_type"
#define BOBY @"body"
#define OUT_TRADE_NO @"out_trade_no"
#define TOTAL_FEE @"total_fee"
#define SIGN @"sign"
#define NONCE_STR @"nonce_str"
#define SPBILL_CREATE_IP @"spbill_create_ip"
#define PREPAYID @"prepayid"
#define PARTNER_ID @"partnerid"
#define PACKAGE @"package"
#define TIMESTAMP @"timestamp"
#define PrepayURL @"https://api.mch.weixin.qq.com/pay/unifiedorder"
#define WXPayResultNotification @"WXPayResultNotification"

#define PayManagerInstance [WHPayManager simpleInstance]

typedef void (^PayCompletionCallBack)(BOOL isSuccess,NSInteger code,NSString * msg);

typedef NS_ENUM(NSUInteger, WXPayResultCode) {
    WXPrepayParamsLosed = 100,      //产品简述、订单号或价格缺失
    WXPrepayApiFailed,              //调用统一下单Api失败
    WXPrepayReturnError,            //调用统一下单Api返回错误
    
    WXPayRequestFailed,             //向微信发送支付请求失败
    WXPayPrepayIdLosed,             //Prepayid为空
    WXPayResponseSuccess = 0,       //支付成功
    WXPayResponseError = -1,        //微信支付结果错误，微信错误码 -1 可能的原因：签名错误、未注册APPID、项目设置APPID不正确、注册的APPID与设置的不匹配、其他异常等
    WXPayResponseCancel = -2,       //用户取消支付 微信码 -2
};

@interface WHPayManager : NSObject

/** 支付相关信息，如AppID，商户ID等，保存在PayInfo.plist中 */
@property (nonatomic, strong) NSDictionary * payInfo;

/** 单例 */
+(instancetype)simpleInstance;

#pragma mark - Alipay

/** 
 *  @brief 支付宝支付
 *  @param params 支付所需参数，以下为必需要的动态参数，其它静态参数在Payinfo.plist中设置
        动态参数:
            orderId                  订单ID
            productName              商品名称
            productDescription       商品描述
            amout                    金额
        静态参数:             
                支付宝商家服务平台https://b.alipay.com/newIndex.htm
                登录->我的商家服务->PID和key
            appID                   上面登录可查看
            seller                  就填商户号即可
            partner                 同上
            service                 极简支付  mobile.securitypay.pay
            notifyURL               支付宝服务器消息回调
            paymetType              1
            inputCharset            utf-8
            itBPay                  30m
            showUrl                 m.alipay.com
            privateKey              这个私钥是生成的，这是生成步骤https://cshall.alipay.com/enterprise/help_detail.htm?help_id=474010&keyword=%C8%E7%BA%CE%C9%FA%B3%C9RSA%C3%DC%D4%BF&sToken=&from=search
            appScheme               URL Type中设置，没有规定值，但设置和使用的要一致
 *  @param completion 支付状态的回调
 */
- (void)AlipayWithParams:(NSDictionary*)params completion:(PayCompletionCallBack)completion;


#pragma mark - Weixin

/**
 *  @brief 微信支付(此方法结合统一下单API操作,如果已从服务器取得prepayid参数,WeiXinPayWithParams:completion:)
 *  @param params 支付所需参数,以下为调用统一下单api所必需的参数，如果还需加入其它参数，看这里https://pay.weixin.qq.com/wiki/doc/api/app.php?chapter=9_1
 *      动态参数(params中带入):
 *          body				商品简要描述
            out_trade_no		商户订单号
            total_fee           支付金额
        静态参数(PayInfo.plist中设置):
            appid               微信开放平台中的注册过的appid https://open.weixin.qq.com
            mah_id              微信支付商户平台的商户号 https://pay.weixin.qq.com
            notify_url          支付成功后微信服务器通知的URL
            key                 微信支付商户平台中的Api密钥
            trade_type          微信支付类型，微信APP支付的值固定为 APP
        其它参数(算法生成):
            nonce_str           随机字符串,小于32位，字母大小写、数字都可以
            sign                签名，是把其它参数按ASCII码从小到大排序，最后拼接及MD5操作后得到的MD5值
            spbill_create_ip    发起统一下单Api的机器ip
 *  @param completion 支付状态的回调
 */
- (void)WeiXinPrePayWithParams:(NSDictionary*)params completion:(PayCompletionCallBack)completion;


/**
 * @brief 微信支付,此方法适用于已知prepayid后调用
 * @param params 支付所需参数
 *        prepayid          预支付id
 * @param completion 支付状态的回调
 */
- (void)WeiXinPayWithParams:(NSDictionary*)params completion:(PayCompletionCallBack)completion;


/**
 * @brief 微信在跳入微信支付后的回调处理
 * @param resp 回调信息
 * e.g.
 -(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
 {
    if ([[options objectForKey:UIApplicationOpenURLOptionsSourceApplicationKey] isEqualToString:@"com.tencent.xin"] && [url.host isEqualToString:@"pay"]) {
        [WXApi handleOpenURL:url delegate:self];
    }
    return YES;
 }
 
 #pragma mark - WXApiDelegate
 
 -(void)onResp:(BaseResp *)resp
 {
    [PayManagerInstance handleWXResult:resp];
 }
 */
- (void)handleWXResult:(BaseResp*)resp;


@end
