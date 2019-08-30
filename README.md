# domainWeakPasswdCheck

# domainAccountCheck-v2.0说明

## 改版说明

1. v1.0运行速度慢
2. v1.0使用稍大一些的字典进行爆破时，很大概率上会卡掉
3. v2.0借助借助hashcat工具进行爆破，速度上有特别大的提升
4. v2.0默认只适用于64位系统，若在32位上使用，需修改domainAccountCheck-v2.ps1脚本

## 文件说明

> - domainAccountCheck-v2.0 为主目录,进入到该目录下运行程序
>   - `domainAccountCheck-v2.ps1`:是运行的主程序
> - Dicts 目录下是字典文件，将需要尝试的密码放进JCPasswd.txt文件中
> - kerberoast目录下是导出ST的凭据所用到的ps脚本
> - hashcat目录下是爆破用到的工具
> - result目录下是包含运行产生的一些结果
>   - `allUserAndSPNList.txt`:用户名与对应的SPN
>   - `allUserList.txt`:所有的域用户账户
>   - `sucSPNList.txt`:成功注册的SPN名称
>   - `sucUserList.txt`:成功注册SPN的用户
>   - `failUserList.txt`:注册SPN失败的用户
>   - `userAndPasswdList.txt`:检查出的域内密码安全性较弱的用户以及相应的口令

## 使用说明

1. > - 将domainWeakPasswdCheck放到一个杀软杀不到的地方，不然，hashcat会被删除，无法进行爆破
   > - 运行程序的计算机要位于域中
   > - 运行程序的账户需要加入域

2. 填充密码字典到Dicts\JCPasswd.txt文件，每行一个密码，ANSI格式保存

3. 以管理员权限运行powershell，设置执行策略

   `Set-ExecutionPolicy RemoteSigned`

4. 进入到domainWeakPasswdCheck目录下的domainAccountCheck-v2.0目录

5. 运行程序

   `.\domainAccountCheck-v2.ps1`

## 版本说明

- v 2.0.0
  - 尝试为域用户账户注册SPN
  - 扫描域中所有存在的SPN
  - hashcat爆破特快
- v 2.0.1 20190830
  - 增加菜单界面
- v 2.1.0 【待做】
  - 使用扫描出来的弱口令，通过LDAP进行一次爆破

# domainAccountCheck-v1.0说明

## 文件说明



> - domainAccountCheck-v2.0为主目录,进入到该目录下运行程序
>   - `requirements.txt`:爆破时需用到python27环境，需要用到的一些包
>   - `domainAccountCheck-v1.ps1`:是运行的主程序
> - Dicts 目录下是字典文件，将需要尝试的密码放进JCPasswd.txt文件中
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

2. 填充密码字典到Dicts\JCPasswd.txt文件，每行一个密码，UTF-8格式保存

3. 安装python2.7环境

4. 安装python依赖包

   `pip install -r requirements.txt`

5. 以管理员权限运行powershell，设置执行策略

   `Set-ExecutionPolicy RemoteSigned`

6. 进入到domainWeakPasswdCheck目录下的domainAccountCheck-v1.0目录

7. 运行程序

   `.\domainAccountCheck-v1.ps1`

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
- v 1.x.x的计划废弃