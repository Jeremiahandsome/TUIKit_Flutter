# TUIKit Flutter

This document introduces **how to quickly run the TUIKit Demo.**

> Please Attention:
> In respect for the copyright of the emoji design, This project does not include the cutouts of large emoji elements. Please replace them with your own designed or copyrighted emoji packs before the official launch for commercial use. The default small yellow face emoji pack is copyrighted by Tencent Cloud and can be authorized for a fee. If you wish to obtain authorization, please [Contact Us](https://trtc.io/contact).
>
> <img src="https://qcloudimg.tencent-cloud.cn/image/document/6438e8feb7bba909511e0d798dfaf91d.png" width="300px" />
>


### Step 1. Create an App
1. Log in to the [Chat Console](https://console.trtc.io/). If you already have an app, record its SDKAppID.
2. On the **Application List** page, click **Create Application**.
3. In the **Create Application** dialog box, enter the app information and click **Confirm**.
> After the app is created, an app ID (SDKAppID) will be automatically generated, which should be noted down.

### Step 2: Obtain Key Information

1. Click **Application Configuration** in the row of the target app to enter the app details page.
2. Click **View Key** and copy and save the key information.
> Please store the key information properly to prevent leakage.

### Step 3: Download and Configure the Demo Source Code

1. Clone this TUIKit_Flutter project.
2. Open the project and locate `chat/demo/lib/login_page.dart`.
3. Set relevant parameters in the `login_page.dart` file:

- SDKAPPID: set it to the SDKAppID obtained in [Step 1](#step1).
- SECRETKEY: enter the key obtained in [Step 2](#step2).

<img src="https://sdk-im-1252463788.cos.ap-hongkong.myqcloud.com/tools/resource/chat/SDKAppID_SecretKey_Flutter.png" width="800"/>


> In this document, the method to obtain UserSig is to configure a SECRETKEY in the client code. In this method, the SECRETKEY is vulnerable to decompilation and reverse engineering. Once your SECRETKEY is leaked, attackers can steal your Tencent Cloud traffic. Therefore, **this method is only suitable for locally running a demo project and feature debugging**.
> The correct `UserSig` distribution method is to integrate the calculation code of `UserSig` into your server and provide an application-oriented API. When `UserSig` is needed, your app can send a request to the business server for a dynamic `UserSig`. For more information, please see [How do I calculate UserSig on the server?](https://trtc.io/document/34385?product=chat&menulabel=serverapis).

### Step 4: Compile and Run the Demo
1. Open `TUIKit_Flutter/chat/demo` with Android Studio.
2. Run `flutter pub get` to obtain plugin dependencies..
3. Connect an Android/iPhone device or start an emulator, and run the demo.

When you run it successfully, you'll see this UI:


<table border="1" bordercolor="#eeeeee" style="border-collapse: collapse;">
  <tr>
    <td align="center" style="padding: 5px;">
      <img src="https://github.com/user-attachments/assets/8027b70b-97f7-4759-88b1-86d422ebe9ae" width="300"/>
    </td>
  </tr>
</table>