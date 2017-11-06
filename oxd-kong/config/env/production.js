'use strict';
/**
 * Production environment settings
 *
 * This file can include shared settings for a production environment,
 * such as API keys or remote database passwords.  If you're using
 * a version control solution for your Sails app, this file will
 * be committed to your repository unless you add it to your .gitignore
 * file.  If your repository will be publicly viewable, don't add
 * any private information to this file!
 *
 */
module.exports = {
  /***************************************************************************
   * Set the default database connection for models in the production        *
   * environment (see config/connections.js and config/models.js )           *
   ***************************************************************************/

  hookTimeout: process.env.KONGA_HOOK_TIMEOUT || 60000,

  kong_admin_url : process.env.KONG_ADMIN_URL || 'http://127.0.0.1:8001',

  // models: {
  //   connection: 'someMysqlServer'
  // },

  /***************************************************************************
   * Set the port in the production environment to 80                        *
   ***************************************************************************/

  port: process.env.KONGA_BACKEND_PORT || 1337,

  /***************************************************************************
   * Set the log level in production environment to "warn"                   *
   ***************************************************************************/
  log: {
      level: "warn"
  },

  // Keep data of response errors in production mode
  keepResponseErrors : true


};
