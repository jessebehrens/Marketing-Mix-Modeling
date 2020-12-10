/*Create a Dataset called MixedData to simulate a table with several fixed effects and a random effect of Geography*/
DATA MixedData;

	/*There are 'four realizations' of our random variable, Geopgrahy. Geography as a random effect explains variance by region.
	  Since we have 4 realziation, the 4 expected value of each estimates will sum to zero.  The purpose of the mixed model is it 
	  allows the model to generalize to generalize to other geographys not in our data.*/
    DO Geo='South','East','North','West';

      /*Random effects must be distributed with a mean of 0. The variance is not fixed, in this case we will set it equal to 5.*/
	  Geo_rand=rand('Normal',0,5);

      /*Simulate 20,000 observation, 5,000 for each geograph*/
      DO i=1 to 5000;
	    /*Define Fixed Effects and Epsilon. Since marketing campaigns are never 0, we are taxking a max value of our output or 0*/
        x1=max(rand('Normal',7.5,1.2),0);
        x2=max(rand('Normal',12.2,1.1),0);
        x3=max(rand('Normal',8.1,1.2),0);
        x4=max(rand('Normal',9.3,.9),0);
        x5=max(rand('Normal',10.5,1),0);
        Epsilon=rand('Normal',0,.05);

        /*Create y for each observation.  The value of y is also dependent on our variance factors*/
        y=10.7 + x1*0.15 + 0.2*x2 + 0.05*x3 + 0.09*x4 + Epsilon + Geo_rand; 
	    Region=Geo;        
        output;
      END;
	END;
  drop i;
RUN;
