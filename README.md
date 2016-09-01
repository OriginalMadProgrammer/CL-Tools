# CL-Tools - Command Line tools for UNIX style shells. 

Assorted command line tools in different languages.

## pushd.pl
Greatly extend the native push/pop, and even cd, commands of shells using a perl script.

The big wins are:

* The ability to symbolically search the stack using path fragments.
* Ability to "rise" entries rather than rotating so popular directories rise to the top of the stack. 
* The ability to preload directory stack during login.
* Child processes inherit parent's stack.
* Nifty cd features borrowed from other shells, sometimes enhanced, now available to all shells. 
* Ability to clean stack of duplicate, non-existant, and other problematic entries.

Though now it requires perl-5, look within and you can see this script's perl-4 herriatage.

