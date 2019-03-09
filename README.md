# ServerPrep
A collection of tools for deploying MS Server and Exchange 2016

A simple collection of helper scripts to quickly setup a domain controller and/or exchange server.

Install-DC
No arguments. Runs powershell command to install the AD-DS Features.

DC-Promo
Promotes Server to Domain Controller. Requires DomainName Paramater and option -AddDC which adds a DC to an existing forest instead of creating a new forest.

Install-ExchPreReq
Installs the 4 Microsoft exchange pre-requiste programs from a given directory. Expects them to be named:
<Fill this in later>

Prepare-Exchange
Run once per domain!
Runs Prepare Schema, AD, and AllDomains.
Catches errors if the schema fails to extend, but if that works, it assumes the other two will.

Install-Exchange
Installs the Mailbx Roll Exchange Server.
