/**
 * Created by pang on 7/10/2016.
 */
'use strict';
var fs = require('fs');
/**
 * Local environment settings
 *
 * While you're DEVELOPING your app, this config file should include
 * any settings specifically for your development computer (db passwords, etc.)
 *
 * When you're ready to deploy your app in PRODUCTION, you can always use this file
 * for configuration options specific to the server where the app will be deployed.
 * But environment variables are usually the best way to handle production settings.
 *
 * PLEASE NOTE:
 *      This file is included in your .gitignore, so if you're using git
 *      as a version control solution for your Sails app, keep in mind that
 *      this file won't be committed to your repository!
 *
 *      Good news is, that means you can specify configuration for your local
 *      machine in this file without inadvertently committing personal information
 *      (like database passwords) to the repo.  Plus, this prevents other members
 *      of your team from committing their local configuration changes on top of yours.
 *
 * For more information, check out:
 * http://links.sailsjs.org/docs/config/local
 */
module.exports = {

  /**
   * The default fallback URL to Kong's admin API.
   */
  kong_admin_url: process.env.KONG_ADMIN_URL || '%(konga_kong_admin_web_url)s',


  connections: {
    postgres: {
      adapter: 'sails-postgresql',
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || '%(pg_pwd)s',
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_DATABASE || 'konga',
      poolSize: process.env.DB_POOLSIZE || 10,
      ssl: process.env.DB_SSL || false
    }
  },

  models: {
    connection: process.env.DB_ADAPTER || 'postgres',
  },

  session: {
    secret: process.env.SESSION_SECRET || '' // Add your own SECRET string here
  },

  ssl: {
    key: fs.readFileSync(process.env.SSL_KEY_PATH || '%(kong_ssl_key)s'),
    cert: fs.readFileSync(process.env.SSL_CERT_PATH || '%(kong_ssl_cert)s')
  },
  hookTimeout: process.env.HOOK_TIMEOUT || 180000, // miliseconds
  port: process.env.PORT || %(konga_port)s,
  environment: 'production',
  log: {
    level: process.env.LOG_LEVEL || 'info'
  },
  oxdWeb: process.env.OXD_SERVER_URL || '%(konga_oxd_web)s',
  opHost: process.env.OP_SERVER_URL || '%(konga_op_host)s',
  oxdId: process.env.OXD_ID || '%(konga_oxd_id)s',
  clientId: process.env.CLIENT_ID || '%(konga_client_id)s',
  clientSecret: process.env.CLIENT_SECRET || '%(konga_client_secret)s',
  oxdVersion: process.env.OXD_SERVER_VERSION || '%(konga_oxd_version)s',
  ggVersion: process.env.GG_VERSION || '%(gg_version)s',
  postgresVersion: process.env.POSTGRES_VERSION || '%(postgres_version)s',
  explicitHost: process.env.EXPLICIT_HOST || 'localhost',
};
