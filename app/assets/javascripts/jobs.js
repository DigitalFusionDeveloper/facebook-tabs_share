if(!window.jobs){
  window.jobs = {};

  window.jobs.count = 0;
  window.jobs.max = 256;
  window.jobs.throttle = 1000;

  window.jobs.complete = function(){};

  jobs.get_next_job = function(){
    Dao.api.call('/jobs/next', function(response){
      job = response['data']['job'];

      if(job){
        jobs.count++;

        jobs.run(job, function(job){
          //console.dir(job);

          if(jobs.count < jobs.max){
            setTimeout(jobs.get_next_job, jobs.throttle);
          }
        });
      }
    });
  };

  jobs.run = function(job, callback){
    var code = job['code'];
    var result = undefined;
    callback = callback || function(){};

//console.log(code);

    if(code){
      try{
        (function(){
          result = eval(code);
        })()
      } catch(e) {};
    }

    job['result'] = result || job['id'];

    var path = '/jobs/' + job['id'];

    var params = {'job' : job};

    Dao.api.put(path, params, function(response){
      job = response['data']['job'];
      jobs.complete(job);
      callback(job);
    });
  };

  try {

    //jobs.get_next_job();

  } catch(e){};

  jobs.start = jobs.get_next_job;
}
