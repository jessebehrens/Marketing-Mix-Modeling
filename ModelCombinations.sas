/*************************************************************\
 This code will create every combination of models.  Because the 
 number of models can grow exponentially, the analyst should be
 careful before running this program. 

 Example: Let's assume there are two predictivee variables
          in a dataset, x1 and x2.  Here we derive two
          transformations off each variable: 
          x1, x1_A50, x1_L1
          x2, x2_A50, x2_L1
 
 There are 3 variables for the x1 group, and 3 variables for 
 the x2 group, so there would be 3*3 = 9 combinations.

 It would not be 26 combinations.  The reason is we only want
 one variable from each group of x1 and x2 in the model.
  
 Warning: Please take the time to manage and track your 
 how many model combinations there are.  The processing 
 can overwhelm a single machine.
\*************************************************************/

/*Delete previous model combination datasets*/
PROC DATASETS lib=work nodetails nolist nowarn;
  delete modelcomb;                            
QUIT;

/*Load all the variables in our analytical dataset into its own dataset*/
PROC CONTENTS data=MIXED_DATA_ADSTOCK_LOG out=finalvars(keep=name) nodetails noprint;
RUN;

/*Put each variable into a group based on the orginal variable it was derived from*/
DATA finalvars;
  set finalvars;
  length var_group $50.;
  
  /*These are variables that will not be used as part of the fixed variables.  They
    are not modeling inputs.
    
  where lowcase(name) not in ('date','epsilon','geo','geo_rand','region','y');
  
  /*Since _A** and _L* are added to the end of every variable, if we strip these
    out, it's easy to get a group name.  For every lag, and adstock added to the
    variable transformations list, it will need to be added here.  These are hardcoded
    for my example.  We can generalize it for your data at another time.*/
    
  var_group =tranwrd(name,'_A05','');
  var_group =tranwrd(var_group ,'_A10','');
  var_group =tranwrd(var_group ,'_A20','');
  var_group =tranwrd(var_group ,'_A30','');
  var_group =tranwrd(var_group ,'_A15','');
  var_group =tranwrd(var_group ,'_A40','');
  var_group =tranwrd(var_group ,'_A50','');
  var_group =tranwrd(var_group ,'_A60','');
  var_group =tranwrd(var_group ,'_A70','');
  var_group =tranwrd(var_group ,'_A80','');
  var_group =tranwrd(var_group ,'_A90','');
  var_group =tranwrd(var_group ,'_A95','');
  var_group =tranwrd(var_group,'_L1','');
  var_group =tranwrd(var_group,'_L2',''); 
  var_group =tranwrd(var_group,'_L3',''); 
  var_group =tranwrd(var_group,'_L4',''); 
  var_group =tranwrd(var_group,'_L5',''); 
  var_group =tranwrd(var_group,'_L6',''); 
  var_group =tranwrd(var_group,'_L7',''); 
  var_group =tranwrd(var_group,'_L8',''); 
  var_group =tranwrd(var_group,'_L9','');
  var_group =tranwrd(var_group,'_L10',''); 
  var_group =tranwrd(var_group,'_L11',''); 
  var_group =tranwrd(var_group,'_L12','');  
RUN;

/*Sort by the newly created var_group variable to put all
 similiar variables together.*/
PROC SORT data=finalvars;
  by var_group;
RUN;

/*Create a count of the number of variables in each group.  This
  will be fed into Proc Transpose as our ID variable*/
DATA finalvars;
  set finalvars;
  by var_group;

  IF first.var_group then count=0;
  count+1;
RUN;

/*Select the biggest max count into a variable &max_count
  This will be use in a later dataset to control variable size
  so there is no truncations*/ 
  
PROC SQL noprint;
  select max(count) into :max_count
  from finalvars;
QUIT;

/*Transpose the data such that each variable is in a row with all other variables
  in the same group*/
PROC TRANSPOSE data=finalvars out=vargroups(drop=_name_ _label_) prefix=var;
var name;
by var_group;
id count;
run;

/*Count the number of var groups for processing and do groups later in the 
  program*/
PROC SQL noprint;
  select count(distinct var_group) into :group_count
  from vargroups;
QUIT;


/*Since each row has a list of all transformations for a single variable, 
  we will concatenate them into a single value*/

DATA vargroups;
  set vargroups;
   
  /*Use &max_count to control length size. This allows us to use a small length
    and keep the size of the dataset as small as possible*/
  length do_var $%sysevalf((&max_count*35)+10).;

  /*Create a single variable with all the variables concatenated together. 
    Any of these variables listed in the groupmust have some derivative in the model.  There is no
    blank string is not added to the end of these variables*/
  IF lowcase(var_group) in ('details','samples','nattvgrp_wgt','spottvgrp','impressions','trend','christmas_flag') then do;
    do_var=compress(catx('',"'",catx("','", of var1-%sysfunc(compress(var&max_count))),"'"));
  END;

  /*This does the same thing as the previous do_var, but adds a blank string to the end
    of each variable because there is a possibility that variable may not need 
    to be in the model*/
  ELSE DO;
    do_var=compress(catx('',catx('',"'",catx("','", of var1-%sysfunc(compress(var&max_count))),"'"),",' '"));
  END;

  call symputx('do_var'||left(_N_),do_var,'G');
RUN;

/*Write all the combinations to the final dataset*/
%macro modelcomb;
data modelcomb;
  /*Find an acceptable length to keep a small dataset but not
    truncate any of the values*/
  length var $%sysevalf((&group_count.*35)+5). var1-%sysfunc(compress(var&group_count)) $32.;
  
  /*I recommend turning options mprint on to understand how this code works*/
  /*The %do loops create a serious of nested datastepsdo loops that iterate through 
    each variable group and outputs the values which in turn creates all variable 
    combinations*/

  /*Create the do statement for each do loop*/
  %do i=1 %to &group_count;
     do var&i=&&do_var&i;
  %end;

  /*Catx all the values of each variable group*/
      var=catx('', of var1-%sysfunc(compress(var&group_count)));
	  if not missing(var) then output;


  /*Create the end statement for each do group*/		
  %do i=1 %to &group_count;
     end;
  %end;
  

  drop var1-%sysfunc(compress(var&group_count));
RUN;

DATA modelcomb;
  set modelcomb;
  /*Create a key so each model output can be tied back to the input variables*/
  key=_N_;
RUN;
%mend;
%modelcomb;

/*Count the total number of model combinations*/
PROC SQL noprint;
  select count(*) into :modelcount
  from modelcomb;
QUIT;
/*Delete unnecessary datasets*/
PROC DATASETS lib=work nodetails nolist nowarn;
  delete finalvars vargroups _temp_;
QUIT;


