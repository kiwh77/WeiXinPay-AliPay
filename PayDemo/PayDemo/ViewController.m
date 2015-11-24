//
//  ViewController.m
//  PayDemo
//
//  Created by 吴浩 on 15/11/20.
//  Copyright © 2015年 kwih77. All rights reserved.
//

#import "ViewController.h"
#import "WHPayManager.h"

#import "ifaddrs.h"
#import <arpa/inet.h>

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate>
@property (nonatomic, strong) UITableView * tableView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"PayDemo";
    [self.view addSubview:self.tableView];
}

#pragma mark - Delegate
#pragma mark UITableViewDelegate & UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * cellIdentifier = @"Cell";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"%zi元",indexPath.row+1];
    return cell;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? @"支付宝" : @"微信(请在真机上调试)";
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString * amout = [NSString stringWithFormat:@"%zi",indexPath.row+1];
    NSString * orderid = randomOrderId();
    NSString * desc = indexPath.section == 0 ? @"支付宝支付测试" : @"微信支付测试";
    NSString * productName = @"测试支付";
    indexPath.section == 0 ?
    [PayManagerInstance AlipayWithParams:@{AMOUNT:amout, ORDER_ID:orderid,DESCRIPTION:desc, PRODUCTNAME:productName} completion:^(BOOL isSuccess, NSInteger code, NSString *msg) {
        NSLog(@"支付宝支付%@ , code : %zi,msg : %@",isSuccess?@"成功":@"失败",code,msg);
    }] :
    [PayManagerInstance WeiXinPrePayWithParams:@{OUT_TRADE_NO:orderid, BOBY:desc, TOTAL_FEE:amout} completion:^(BOOL isSuccess, NSInteger code, NSString *msg) {
        NSLog(@"微信支付%@,code : %zi,msg : %@",isSuccess?@"成功":@"失败",code,msg);
    }];
}


#pragma mark - Action

NSString * randomOrderId(){
    char * ch = "0123456789";
    NSMutableString * result = [NSMutableString string];
    for (int i=0; i<15; i++) {
        int index = rand()%10;
        char c = ch[index];
        [result appendFormat:@"%c",c];
    }
    return result;
}

#pragma mark - Set & Get

-(UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableFooterView = UIView.new;
        _tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    return _tableView;
}

@end
