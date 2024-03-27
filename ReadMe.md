# WakeUp: send device(s) the Magic Packet ;)

This script sends "Magic Packets" to devices on the local network. See AMD's white paper *[Magic Packet Technology](https://www.amd.com/content/dam/amd/en/documents/archived-tech-docs/white-papers/20213.pdf)* for a description of the Magic Packet.

The script sends the Magic Packet over all active network interfaces on the local system using IPv4, IPv6, or both if both are configured on the interface. This implies a target may receive two Magic Packets.

The script behaves slightly differently in "Command Line Mode" or in "Interactive Mode".

<details><summary>"Command line" mode</summary>
Command line mode is presumed when at least one MAC address is specified in the script invocation.

Usage: wakeup [-NoScan] [-Delay n] -Target MAC1,MAC2,...,MACn
Where
- -NoScan is an optional parameter ignored in command line mode
- -Delay is the number of seconds to wait for the target(s) to connect to their network(s). The default value is 60 seconds.
- -Target (and its alias Targets) is a (comma separated list of) MAC address(es). MAC addresses can be specified using any delimiter (except a comma ;).


Example:
````
PS C:\Users\ThisUser\Desktop\WakeUp> ./wakeup -delay 20 -Targets 00-00-C0-2B-99-93,00-00-C0-1F-27-AA
Targeting vEthernet (Default Switch) (Hyper-V Virtual Ethernet Adapter) ... Done.
Targeting $Switch Untagged (Hyper-V Virtual Ethernet Adapter #2) ... Done.
Warning: Waiting 20 seconds for the target(s) to connect to their network(s)...
PS C:\Users\ThisUser\Desktop\WakeUp>

````

</details>


<details><summary>Interactive mode</summary>
Execute this script using a right-click "Run with PowerShell" or from a terminal window without the -Target parameter.

This allows you to select a simple text file containing a list of hostname and MAC address, one per line, such as:
````
Week1	00-00-C0-2B-99-93
Week2	00-00-C0-1F-27-AA
BadRomance	UN-de-FI-NE-d0-ff
Week3	00-00-C0-1F-2A-BC

````
Anything that does not translate to 12 hexadecimal digits is simply ignored.

The actual targets are selected using a grid: this avoids waking up every host on the list while keeping a single configuration file.

Unlike "Command Line Mode", there is a hostname to ping: the local system reports the interface used to connect to this host, its remote address, and the interface local address as well as the round trip time (RTT). This verifies that each remote host is alive.

Usage: wakeup [-NoScan] [-Delay n]
Where
- -Delay is the number of seconds to wait for the target(s) to connect to their network(s). The default value is 60 seconds.
- -NoScan is an optional parameter to avoid pinging each target once the delay is elapsed.




````
Targeting vEthernet (Default Switch) (Hyper-V Virtual Ethernet Adapter) ... Done.
Targeting $Switch Untagged (Hyper-V Virtual Ethernet Adapter #2) ... Done.
Warning: Waiting 60 seconds for the target(s) to connect to their network(s)...                                                                                                                                                                                                                                                                                  
ComputerName           : Week1                                                                                       
RemoteAddress          : 192.168.18.21                                                                                  
InterfaceAlias         : $Switch Untagged                                                                               
SourceAddress          : 192.168.18.31
PingSucceeded          : True
PingReplyDetails (RTT) : 2 ms

ComputerName           : Week2
RemoteAddress          : 192.168.18.23
InterfaceAlias         : $Switch Untagged
SourceAddress          : 192.168.18.31
PingSucceeded          : True
PingReplyDetails (RTT) : 0 ms

ComputerName           : Week3
RemoteAddress          : 192.168.18.17
InterfaceAlias         : $Switch Untagged
SourceAddress          : 192.168.18.31
PingSucceeded          : True
PingReplyDetails (RTT) : 0 ms

Press Enter to continue ...:

````
</details>



