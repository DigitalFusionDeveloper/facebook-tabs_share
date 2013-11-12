if(!window.jobs){
//
  window.jobs = {};
  window.jobs.count = 0;
  window.jobs.max = 256;
  window.jobs.throttle = 1000;
  window.jobs.complete = function(){};

//
  jobs.get_next_job = function(){
    var success = function(response){
      job = response['data']['job'];

      if(job){
        jobs.count++;

        jobs.run(job, function(job){
          if(jobs.count < jobs.max){
            setTimeout(jobs.get_next_job, jobs.throttle);
          }
        });
      }
    };

    jQuery.ajax({
      'url'     : '/api/jobs/next',
      'type'    : 'GET',
      'cache'   : false,
      'success' : success
    });
  };

//
  jobs.run = function(job, callback){
    var code = job['code'];
    var result = undefined;

    callback = callback || function(){};

    if(code){
      try{
        (function(){

          job['result'] = eval(code);

        })()
      } catch(e) {};
    }

    var url = '/api/jobs/:id'.replace(/:id/, job['id']);

    var data = {'job' : job};

    var success = function(response){
      job = response['data']['job'];

      try{
        jobs.complete(job);
      } catch(e){};

      try{
        callback(job);
      } catch(e){};
    };

    jQuery.ajax({
      'url'      : url,
      'type'     : 'PUT',
      'cache'    : false,
      'data'     : {'job'  : job},
      'dataType' : 'json',
      'success'  : success
    });
  };

//
  jobs.start = jobs.get_next_job;
}
