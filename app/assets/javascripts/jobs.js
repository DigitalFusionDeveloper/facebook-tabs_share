if(!window.jobs){
  window.jobs = {};

  window.jobs.count = 0;
  window.jobs.max = 3;
  window.jobs.throttle = 100;

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

    if(code){
      try{
        (function(){
          result = eval(code);
        })()
      } catch(e) {};
    }

    job['result'] = result;

    var path = '/jobs/' + job['id'];

    var params = {'job' : job};

    Dao.api.put(path, params, function(response){
      job = response['data']['job'];
      callback(job);
    });
  };

  try {

    jobs.get_next_job();

  } catch(e){};
}
