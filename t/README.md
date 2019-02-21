Microframework for testing Kong plugins.

This git repository has some submodules, use recursive clone.

It uses the latest 0.14 Kong!!! 
New Service/Route objects are used and PDK framework.

Dependencies
============

The only dependency to run this test suite is docker-ce.

If you have older Docker installer - remove it (Debian based distro considered):

`sudo apt-get remove docker docker-engine docker.io`

The simplest way to install docker-ce is as below (old distros may be not supported):

`curl http://get.docker.com/ | sudo sh`

General layout
==============

`specs` subfolder should contains fully automated tests only.

`flows` subfolder should contains test suites which require external server for testing, for example oxd and gluu servers.
It may require some provisioning from a test runner.
TODO - at the moment a programmer must hardcode servers' address/port within test.

'lib' subfolder contains a files which may be reused by different tests.


How to test
===========

```
./t/run.sh
``` 

The test case start all required services, register a Service, then Route, configure demo plugin.


Mock oxd-server
===============

It uses mock oxd server.
Every test case uses a oxd Lua model which defines the sequence of expected endpoints calls and responses.
Some test cases share a model, some tests use it is owm model.

