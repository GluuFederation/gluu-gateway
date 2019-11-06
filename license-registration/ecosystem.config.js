module.exports = {
  apps : [{
    name: 'gg_license',
    script: 'src/index.js',
    instances: 1,
    autorestart: true,
    watch: false,
  }]
};
