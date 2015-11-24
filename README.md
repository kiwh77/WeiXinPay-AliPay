WHPayManager
---

* 一行代码发起支付，Block回调支付结果
* 参数使用plist配置，修改参数，不用改代码
* 更多请看[这里](http://blog.csdn.net/kiwh77/article/details/50010705)

---

####WHPayManager使用说明
1. 创建PayInfo.plist文件，在文件里根据需求分别创建`Alipay`和`WXPay`两个分支，再分别填入所需的参数，推荐直接复制Demo中的PayInfo.plist
2. 导入支付宝和微信的SDK
3. 导入Demo中的Order模型，用于支付宝


####Demo运行需知
* 需要在`PayInfo.plist`中填入相应的信息，这些信息包括appid，商户id等
