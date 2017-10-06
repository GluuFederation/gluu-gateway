const jwt = require('jsonwebtoken');
const express = require('express');
const request = require('request-promise');
const httpStatus = require('http-status');
const router = express.Router();

router.get('/login', (req, res) => {
  if (!!req.query.code && !!req.query.state) {
    var clientToken = '';
    return getClientAccessToken()
      .then(token => {
        clientToken = token;
        const option = {
          method: 'POST',
          headers: {
            Authorization: 'Bearer ' + clientToken
          },
          uri: process.env.OXD_WEB + '/get-tokens-by-code',
          body: {
            oxd_id: process.env.OXD_ID,
            code: req.query.code,
            state: req.query.state
          },
          resolveWithFullResponse: true,
          json: true
        };

        return request(option);
      })
      .then(response => {
        const codeToken = response.body;
        const option = {
          method: 'POST',
          headers: {
            Authorization: 'Bearer ' + clientToken
          },
          uri: process.env.OXD_WEB + '/get-user-info',
          body: {
            oxd_id: process.env.OXD_ID,
            access_token: codeToken.data.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        return request(option);
      })
      .then(response => {
        const userInfo = response.body;

        if (userInfo.status === 'error') {
          return Promise.reject(userInfo.data)
        }
        let token = jwt.sign(userInfo, process.env.APP_SECRET, {
          expiresIn: process.env.JWT_EXPIRES_IN
        });

        return res.send({user: userInfo, role: 'manager', token: token});
      })
      .catch(error => {
        return res.status(httpStatus.INTERNAL_SERVER_ERROR).send({error: error});
      });
  }

  return getClientAccessToken()
    .then(token => {
      const option = {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + token
        },
        uri: process.env.OXD_WEB + '/get-authorization-url',
        body: {
          oxd_id: process.env.OXD_ID,
          scope: ['openid', 'email', 'profile', 'uma_protection', 'permission']
        },
        resolveWithFullResponse: true,
        json: true
      };

      return request(option);
    })
    .then(response => {
      const urlData = response.body;

      if (urlData.status === 'error') {
        return Promise.reject(urlData.data)
      }

      return res.send({authURL: urlData.data.authorization_url});
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send({error: error});
    });
});

function getClientAccessToken() {
  let option = {
    method: 'POST',
    uri: process.env.OXD_WEB + '/get-client-token',
    body: {
      client_id: process.env.CLIENT_ID,
      client_secret: process.env.CLIENT_SECRET,
      scope: ['openid', 'email', 'profile', 'uma_protection'],
      op_host: process.env.OP_HOST
    },
    resolveWithFullResponse: true,
    json: true
  };

  return request(option)
    .then(response => {
      const tokenData = response.body;

      if (tokenData.status === 'error') {
        return Promise.reject(tokenData.data)
      }

      return Promise.resolve(tokenData.data.access_token);
    })
}
module.exports = router;