#!/usr/bin/python3
#
# Print clouds/secure.yaml config without disclosing the password/token/appcred
# This would be a lot easier with using pyaml
#

import sys, os, string, getopt

repl_list={}
inj_list={}

def usage():
    print("Usage: print_cloud.py [OPTIONS] [CLOUD [CLOUD [..]]]", file=sys.stderr)
    print("OPTIONS: --cloud CLOUD: Replace cloud name", file=sys.stderr)
    print("         --replace attr=value", file=sys.stderr)
    print("         --inject attr=value", file=sys.stderr)
    return 1

def countws(st):
    idx = 0
    while idx < len(st) and st[idx].isspace():
        idx += 1
    return idx

def output_nonsecret(ln):
    kwds = ln.split(':')
    idx = countws(kwds[0])
    if kwds[0][idx:] in repl_list:
        print("%s: %s" % (kwds[0], repl_list[kwds[0][idx:]]))
    elif kwds[0][idx:] in inj_list:
        print("%s%s" % (kwds[0][:idx], inj_list[kwds[0][idx:]]))
        print(ln)
    elif 'password' in kwds[0] or 'secret' in kwds[0] or 'token' in kwds[0]:
        print('%s: SECRET' % kwds[0])
    else:
        print(ln)

def findcloud(cloudname, fn):
    if not os.access(fn, os.R_OK):
        return False
    f = open(fn, "r")
    found = False
    nextind = False
    indent = "  "
    lenind = len(indent)
    for line in f:
        line = line.rstrip('\r\n')
        if line == "---":
            continue
        if line == "clouds:":
            #print("Found clouds:")
            nextind = True
            continue
        if not line or (line and line[0] == "#") or not line.rstrip(string.whitespace):
            continue
        if nextind:
            for lenind in range(0, len(line)-1):
                if line[lenind] not in string.whitespace:
                    break
            assert(lenind != len(line)-1 and lenind != 0)
            indent = line[0:lenind]
            #print("Indentation: \"%s\"" % indent)
            nextind = False
        if not found and line == "%s%s:" % (indent, cloudname):
            found = True
            print("---\n#Cloud %s in %s:\nclouds:" % (cloudname, fn))
            #output_nonsecret(line)
            if 'cloud' in repl_list:
                print("%s%s" % (indent, repl_list["cloud"]))
            else:
                print("%s%s" % (indent, cloudname))
            continue
        if not found:
            continue
        if line[:lenind] != indent or line[lenind:lenind+1] not in string.whitespace:
            #print("END: %s" % line)
            return found
        output_nonsecret(line)
    return found

def main(argv):
    global repl_list, inj_list
    home = os.environ["HOME"]
    err = 0
    try:
        optlist, arg = getopt.gnu_getopt(argv, "c:r:i:h", ('--cloud=', '--replace=', '--inject='. '--help'))
    except getopt.GetoptError as exc:
        print("Error:", exc, file=sys.stderr)
        sys.exit(usage())
    for opt in optlist:
        if opt[0] == '-h' or opt[0] == '--help':
            usage()
            sys.exit(0)
        elif opt[0] == '-c' or opt[0] == '--cloud':
            repl_list['cloud'] = opt[1]
        elif opt[0] == '-r' or opt[0] == '--replace':
            pair = opt[1].split('=')
            repl_list[pair[0]] = pair[1]
        elif opt[0] == '-i' or opt[0] == '--inject':
            pair = opt[1].split('=')
            inj_list[pair[0]] = pair[1]
        else:
            sys.exit(usage())

    if not len(arg) and "OS_CLOUD" in os.environ:
        arg = (os.environ["OS_CLOUD"],)
    for cloud in arg:
        success = False
        for (cyaml,syaml) in (("./clouds.yaml", "./secure.yaml"),
                    ("%s/.config/openstack/clouds.yaml" % home, "%s/.config/openstack/secure.yaml" % home),
                    ("/etc/openstack/clouds.yaml", "/etc/openstack/secure.yaml")):
            success = findcloud(cloud, cyaml)
            if success:
                findcloud(cloud, syaml)
                break
        if not success:
            print("#Cloud config for %s not found"% cloud) 
            err += 1
    return err

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
