## More than just another GUI to [KONG Admin API](http://getkong.org)    [![Build Status](https://travis-ci.org/pantsel/konga.svg?branch=master)](https://travis-ci.org/pantsel/konga)    [![Gitter chat](https://badges.gitter.im/pantsel-konga/Lobby.png)](https://gitter.im/pantsel-konga/Lobby)

[![konga-logo.png](screenshots/konga-logo.png)](screenshots/konga-logo.png?raw=true)


[![Dashboard](screenshots/bc2.png)](screenshots/bc2.png?raw=true)

<em>Konga is not an official app. No affiliation with [Mashape](https://www.mashape.com/).</em>

## Summary

- [**Prerequisites**](#prerequisites)
- [**Used libraries**](#used-libraries)
- [**Installation**](#installation)
- [**Configuration**](#configuration)
- [**Running Konga**](#running-konga)

## Prerequisites
- A running [Kong installation](https://getkong.org/) 
- Nodejs
- Npm

## Used libraries
* Sails.js, http://sailsjs.org/

    Command to install sails js
    ```
    npm install sails -g
    ```

## Installation

Install <code>npm</code> and <code>node.js</code>. Instructions can be found [here](http://sailsjs.org/#/getStarted?q=what-os-do-i-need).

Install <code>bower</code> and <code>gulp</code> packages.
<pre>
$ npm install bower -g
$ npm install gulp -g
</pre>


<pre>
$ git clone https://github.com/GluuFederation/kong-plugins
$ cd konga
$ npm install
$ npm bower-deps
</pre>

## Configuration
You can configure your  application to use your environment specified
settings.

This is property file where you need to specify port, oxd, OP and client settings.

<pre>
/config/local.js
</pre>

## Running Konga

### Development
<pre>
$ npm start
</pre>
Konga GUI will be available at `https://localhost:1337`

#### Login
You need to make self sign certificate file i:e key.pem and cert.pem and put them in /konga folder for run application on https.

Also need to make client with `https://localhost:1337` authorization url using oxd-https-extension.

Click on login button and according to configuration in local.js that it goes for oAuth authentication.
