# scriptclerk
Script Clerk, automation for managing multiple services, applications and configurations in a development environment.

Improve software development time by automating the managment and setup of applications 
and services. This can become problematic during development of larger software projects 
where multiple services, applications and configurations are needed. Many designs these
days are moving to micro-services, which can be a pain to manage during development. 

Script Clerk can autostart a range of services and applications. The automated
patching feature allows for easily configuration of the system for test setups 
without needing to commit the changes to the code repository. 

Removing and applying configuration option patches for a test environment can be a 
high time overhead. Especially when needing to switch branches frequently to work 
on different features. Script Clerk was built to address this time overhead.

Helpful Notes:
* Assumes that a git repo is available in the current working directory and will not be able to manage patches without one.
* If you want to auto-build before running applications, the BUILD variable needs to be changed to whatever command you need to clean and make your software project. The BUILD variable is found at the start of the Script Clerk script.
* The auto-build occurs after the auto-patch, so code patches will be applied to your build.
* Can be useful for automating a range of test environments.
