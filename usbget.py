#!/usr/bin/python
import sys
import subprocess
import getpass
import os
import threading
import Queue

global v
v = -1 

# Check for the log directories, if not there create them
for logdir in ["./log","./log/new","./log/current","./log/change"]:
    if not os.path.isdir(logdir):
        os.mkdir(logdir)

def prep(host,user,pwd):
    # Upload Script, Create Service
    return subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "put gua.ps1" """),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(('net rpc service create -I ' + host + " -U '" + user + "%" + pwd + """' USBMONsvc USBMON "cmd /c powershell.exe -executionpolicy bypass -File \\\\\\127.0.0.1\\admin$\gua.ps1 -System" """),shell=True, stdout=v, stderr=subprocess.STDOUT)

def run(host,user,pwd):
    # Start the service
    return subprocess.call(('net rpc service start -I ' + host + " -U '" + user + "%" + pwd + "' USBMONsvc"),shell=True, stdout=v, stderr=subprocess.STDOUT) 
    
def retrieve(host, user, pwd):
    # Retrieve results
    return subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "get guaresults.txt ./log/new/""" + host + '"'),shell=True, stdout=v, stderr=subprocess.STDOUT)

def clean(host,user,pwd):
    # Delete Service, Script, and output file
    subprocess.call(('net rpc service delete -I ' + host + " -U '" + user + "%" + pwd + "' USBMONsvc"),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "del gua.ps1" """),shell=True, stdout=v, stderr=subprocess.STDOUT), subprocess.call(("smbclient //" + host + "/admin$ " + pwd + " -U '" + user + """' -c "del guaresults.txt" """),shell=True, stdout=v, stderr=subprocess.STDOUT)

def update(host):
    if os.path.isfile("./log/current/" + host) and os.path.isfile("./log/new/" + host):
        if open("./log/current/" + host).read() != open("./log/new/" + host).read():
            # Write to changelog, replace current with new
            return subprocess.call(("cat ./log/current/" + host + " ./log/new/" + host + " > ./log/change/" + host),shell=True, stdout=v, stderr=subprocess.STDOUT) , subprocess.call(("mv ./log/new/" + host + " ./log/current/"),shell=True, stdout=v, stderr=subprocess.STDOUT)
    return subprocess.call(("mv ./log/new/" + host + " ./log/current/"),shell=True, stdout=v, stderr=subprocess.STDOUT)

def main():

    # Warn the user about permission issue
    if os.getuid() != 0:
        print "WARNING: YOU ARE NOT ROOT, THIS MAY CAUSE ISSUES"

    global v
    argtargets = False
    argthreads = False
    bprep = False
    brun = False
    bget = False
    bclean = False
    bupdate = False
    bcmd = False
    hosts = {}
    pwds = {}
    threads = 3 

    for arg in sys.argv:
        if arg == "-h" or arg == "--help":
            print "usage: usbget.py user@IP(s) [command] [arguments]\n\nMonitor USB usage on remote hosts.\n\noptional commands:\n  prep              prepare target host\n  run               run script on target\n  get               retrieve results\n  clean             delete all usbget files from target\n  update            update log directory with new information\n\noptional arguments:\n  -t  --threads     number of threads (default: 3)\n  -v  --verbose     Be Verbose\n  -h  --help        show this help message and exit\n\nexamples:\n  usbmon.py luke@10.1.1.20-22 luke@10.1.2.1-5\n  usbmon.py luke@10.1.3.10,11 mike@10.1.1.6-9\n  usbmon.py luke@10.1.1.1,10.1.3.2 clean -v -t 1"
            exit()
        elif arg == "-v" or arg == "--verbose":
            v = 2
        if arg == "-t" or arg == "--threads":
            try:
                threads = int(sys.argv[sys.argv.index("-t")+1])
                argthreads = True
            except:
                sys.exit("""ERROR: "threads" provided is not an int.""")
        elif arg.count(".") >= 3 and "@" in arg:
            # Clear targets
            targets=[]
            # Parse user
            user = arg.split("@")[0]
            # allows support for user1@10.1.1.1 user1@10.1.1.2 
            if not user in hosts.keys():
                hosts[user]=[]
            # Parse IP of user@IP
            IP = arg.split("@")[1]
            argtargets = True
            if "-" in IP or "," in IP:
                if "-" in IP:
                    targets.append(IP.split("-")[0])
                    if (int(IP.split("-")[1]) < int(IP.split("-")[0].split(".")[3])):
                        # 10.1.1.5-1
                        for i in range(int(IP.split("-")[0].split(".")[3]) - int(IP.split("-")[1])):
                            targets.append(".".join(IP.split("-")[0].split(".")[:3]) + "." + str(int(IP.split("-")[0].split(".")[3]) - i - 1))
                    else:
                        # 10.1.1.1-5
                        for i in range(int(IP.split("-")[1]) - int(IP.split("-")[0].split(".")[3])):
                            targets.append(".".join(IP.split("-")[0].split(".")[:3]) + "." + str(int(IP.split("-")[0].split(".")[3]) + i + 1))
                    hosts[user]+=targets
                if "," in IP:
                    if len(IP.split(",")[1]) > 3:
                        # 10.1.1.1,10.1.1.2
                        hosts[user] += IP.split(",")
                    else:
                        # 10.1.1.1,2,3
                        targets.append(IP.split(",")[0])
                        for fourthquarter in IP.split(",")[1:]:
                            targets.append(".".join(IP.split(".")[:3]) + "." + fourthquarter)
                        hosts[user]+=targets
            else:
                # 10.1.1.1
                hosts[user].append(IP)
            
            # Remove Duplicates
            seen = set()
            seen_add = seen.add
            hosts[user] = [ x for x in hosts[user] if x not in seen and not seen_add(x)]
        elif arg.lower() == "prep":
            bprep = True
        elif arg.lower() == "run":
            brun = True
        elif arg.lower() == "get":
            bget = True
        elif arg.lower() == "clean":
            bclean = True
        elif arg.lower() == "update":
            bupdate = True

    # bcmd is true if the user is using a command
    if bprep or brun or bget or bclean or bupdate == True:
        bcmd = True

    # check for hosts
    if len(hosts.keys()) == 0:
        sys.exit("No target hosts specified.")

    # create the queue for the threads to refer to
    ToDo = Queue.Queue()

    # start all the threads
    for i in range(threads):
        thread = threading.Thread(target=worker, args=(ToDo,bcmd,bprep,brun,bget,bclean,bupdate))
        thread.daemon = True
        thread.start()
    
    for user in hosts.keys():
        ## Grab Password 
        for i in range(3):
            pwds[user] = getpass.getpass(user + "'s password: ")
            if pwds[user] != "":
                break
            if i == 2:
                sys.exit("You must enter a password.")

        # loop through hosts and add them to the queue 
        for host in hosts[user]:
                ToDo.put([host,user,pwds[user]])

    ToDo.join()

def worker(ToDo, bcmd, bprep, brun, bget, bclean, bupdate):
    get=ToDo.get()
    host,user,pwd=get[0],get[1],get[2]

    fail=0
    if not bcmd or bprep:
        retcode = prep(host,user,pwd)
        if 1 in retcode:
            fail=2
            print host + ": LOGON FAILURE"
        else:
            print host + ": PREPARATION DONE"
        
    if (not bcmd or brun) and fail==0:
        retcode = run(host,user,pwd)
        if retcode == 1:
            fail=1
            print host + ": EXECUTION FAILURE"
        else:
            print host + ": EXECUTION DONE"
        
    if (not bcmd or bget) and fail==0:
        retcode = retrieve(host,user,pwd)
        if retcode == 1:
            fail=1
            print host + ": RESULTS FILE NOT FOUND"
        else:
            print host + ": RETRIEVAL DONE"
       
    if (not bcmd or bclean) and fail<2:
        clean(host,user,pwd)
        print host + ": CLEANING DONE"
          
    if (not bcmd or bupdate) and fail==0:
        update(host)
        print host + ": UPDATE DONE"

    ToDo.task_done()

if __name__ == "__main__":
    main()

