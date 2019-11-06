const mongoose = require('mongoose');

// define the schema for our metrics
const metricsSchema = mongoose.Schema({
  metrics_host: {
    type: String,
    required: true,
    unique: true,
  },
  email: {
    type: String,
    required: true,
  },
  organization: {
    type: String,
  },
}, {
  timestamps: true
});

metricsSchema.statics = {
  search(params) {
    //count documents https://stackoverflow.com/questions/43925662/mongoose-pagination-from-server-side

    return this.count({})
      .then((count) => {
        if (count === 0) {
          return Promise.reject({msg: 'No Document in Database..'});
        }
        return Promise.resolve(count);
      })
      .then((count) => {
        //get paginated documents
        return this.find().skip(params.pagination.start).limit(params.pagination.number).exec().then(function (docs) {
          if (!docs) {
            return Promise.reject({msg: 'No Document in Database..'});
          } else {
            const result = {
              totalRecords: count,
              numberOfPages: Math.ceil(count / params.pagination.number),
              data: docs
            };
            return Promise.resolve(result);
          }
        });
      })
      .catch((err) => Promise.reject(err));
  }
};

module.exports = mongoose.model('Metrics', metricsSchema);
