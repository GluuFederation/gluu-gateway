/**
 * Created by user on 07/10/2017.
 */

'use strict'

var moment = require("moment");
var _ = require("lodash");

module.exports = {

    getMinutesDiff : function(start,end) {
        var duration = moment.duration(moment(start).diff(moment(end)));
        return duration.asMinutes();
    },

    getAdminEmailList : function(cb) {
        sails.models.user.find({
            admin : true
        }).exec(function(err,admins){
            if(err) return cb(err)
            if(!admins.length) return cb([])
            return cb(null,admins.map(function(item){
                return item.email;
            }));
        });
    },

    sendSlackNotification : function(settings,message) {

        var slack = _.find(settings.data.integrations,function(item){
            return item.id == 'slack'
        })

        if(!slack || !slack.config.enabled) return;

        // Send notification to slack
        var IncomingWebhook = require('@slack/client').IncomingWebhook;

        var field = _.find(slack.config.fields,function(item){
            return item.id == 'slack_webhook_url'
        })

        var url = field ? field.value : "";

        var webhook = new IncomingWebhook(url);

        webhook.send(message, function(err, header, statusCode, body) {
            if (err) {
                console.log('Error:', err);
            } else {
                console.log('Received', statusCode, 'from Slack');
            }
        });
    },
}