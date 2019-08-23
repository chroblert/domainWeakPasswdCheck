# domainWeakPasswdCheck

# domainAccountCheck说明

## 文件说明



> - domainWeakPasswdCheck 为主目录
>   - `requirements.txt`:爆破时需用到python27环境，需要用到的一些包
>   - `domainAccountCheck.ps1`:是运行的主程序
> - Dicts 目录下是字典文件，将需要尝试的密码放进GaiaPasswd.txt文件中
> - kerberoast目录下是最后爆破需要用到的python文件
> - mimikatz目录下是导出票据是要用到的工具，64位
> - result目录下是包含运行产生的一些结果
>   - `allUserAndSPNList.txt`:用户名与对应的SPN
>   - `allUserList.txt`:所有的域用户账户
>   - `sucSPNList.txt`:成功注册的SPN名称
>   - `sucUserList.txt`:成功注册SPN的用户
>   - `failUserList.txt`:注册SPN失败的用户
>   - `userAndPasswdList.txt`:检查出的域内密码安全性较弱的用户以及相应的口令

## 使用说明

1. > - 将domainWeakPasswdCheck放到一个杀软杀不到的地方，不然，mimikatz会被删除，无法获取到缓存的ST凭据
   > - 运行程序的计算机要位于域中
   > - 运行程序的账户需要加入域

2. 填充密码字典到Dicts\GaiaPasswd.txt文件，每行一个密码，utf-8格式保存

3. 安装python2.7环境

4. 安装python依赖包

   `pip install -r requirements.txt`

5. 以管理员权限运行powershell，设置执行策略

   `Set-ExecutionPolicy RemoteSigned`

6. 进入到domainWeakPasswdCheck目录下

7. 运行程序

   `.\domainAccountCheck.ps1`

## 版本说明

- v 1.0.0
  - 缺少多线程支持
  - 需要有为域用户账户注册SPN的权限
- v 1.1.0 【待做】
  - 增加：在没有注册SPN权限的情况下，扫描当前已经以域用户账户身份注册的SPN
  - 增加LDAP爆破
- v 1.2.0 【待做】
  - 增加：进度条展示
- v 1.3.0 【待做】
  - 增加：多线程支持