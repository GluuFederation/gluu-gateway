const httpStatus = require('http-status');
const metrics = require('./metrics.helper');
const yaml = require('js-yaml');
const fs = require('fs');
const exec = require('child_process').exec;

function search(req, res) {
  metrics.getMetricsBySearch(req.body)
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
};

function getAll(req, res) {
  metrics.getAllMetrics()
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

function getById(req, res) {
  metrics.getMetricsById(req.params.id)
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

function registration(req, res) {
  metrics.registration(req.body)
    .then(metrics => {
      // Read the prometheus configuration
      const doc = yaml.safeLoad(fs.readFileSync(process.env.PROMETHEUS_YML, 'utf8'));
      let targets = doc.scrape_configs[1].static_configs[0].targets;

      if (targets.indexOf(metrics.metrics_host) > -1) {
        return res.send(metrics);
      }

      targets.push(metrics.metrics_host);
      console.log('----- scrape_configs targets ------', targets, '-----------');
      const updatedYaml = yaml.safeDump(doc);
      console.log('----- Update yml ---------', updatedYaml);

      fs.writeFile(process.env.PROMETHEUS_YML, updatedYaml, function (err) {
        if (err) {
          console.log(err);
          return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(err);
        }
        console.log('----- Prometheus yml file updated successfully ---------');
        console.log('----- Restarting prometheus server -------');
        exec('pm2 restart ' + process.env.PROMETHEUS_PM2_PROCESS, (err, stdout, stderr) => {
          if (err) {
            console.log('Failed to restart server')
          }

          console.log(`stdout: ${stdout}`);
          console.log(`stderr: ${stderr}`);
        });
      });
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

function add(req, res) {
  metrics.addMetrics(req.body)
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

function update(req, res) {
  metrics.updateMetrics(req.body, req.params.id)
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

function remove(req, res) {
  metrics.removeMetrics(req.params.id)
    .then(metrics => {
      return res.send(metrics);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
}

module.exports = {
  search,
  getAll,
  getById,
  add,
  registration,
  update,
  remove,
};
