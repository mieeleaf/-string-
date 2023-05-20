`timescale 1ns/10ps
module SME(clk,reset,chardata,isstring,ispattern,valid,match,match_index);
input clk;
input reset;
input [7:0] chardata;
input isstring;
input ispattern;
output match;
output [4:0] match_index;
output valid;
reg match;
reg [4:0] match_index;
reg valid;
reg [7:0] str_mem[31:0];
reg [4:0] count_str;
reg [7:0] pat_mem[7:0];
reg [2:0] count_pat;
reg [4:0] str_length;
reg [2:0] pat_length;
reg [8:0] str_index_cs;
reg [3:0] pat_index_cs;
reg [8:0] str_index_ns;
reg [3:0] pat_index_ns;


reg [2:0]bm_cs;
reg [2:0]bm_ns;

reg [1:0]mode_cs;
reg [1:0]mode_ns;

reg [3:0]shift_str_cs;
reg [3:0]shift_str_ns;

parameter READ_STR=2'b00,READ_PAT=2'b01,COMPARE_PAT=2'b10,STR_OR_PAT=2'b11;
parameter BM0=3'b000,BM1=3'b001,BM2=3'b010,BM3=3'b011,BM4=3'b100,BM5=3'b101,BM6=3'b110;

always@(posedge clk or posedge reset)
  begin
    if(reset)
   begin
     mode_cs<=READ_STR;
   end
 else
   begin
     mode_cs<=mode_ns;
   end
  end

always@(*)
  begin
    case(mode_cs)
   READ_STR:  begin
                if(isstring)
         mode_ns=READ_STR;
       else
         mode_ns=READ_PAT;
        end
   READ_PAT:  begin
                if(ispattern)
         mode_ns=READ_PAT;
       else
         mode_ns=COMPARE_PAT;
        end
   COMPARE_PAT:begin
                if(valid)
         mode_ns=STR_OR_PAT;
       else
         mode_ns=COMPARE_PAT;
         end
   STR_OR_PAT:begin
       if(isstring)
         mode_ns=READ_STR;
       else if(ispattern)
         mode_ns=READ_PAT;
       else 
         mode_ns=STR_OR_PAT;
     end
   default:mode_ns=READ_STR;
 endcase
  end


   
always@(negedge clk or posedge reset)
  if(reset)
    begin
      pat_index_cs<=0;
      str_index_cs<=0;
       bm_cs<=0;
       shift_str_cs<=0;
 end
  else
  begin
 case(mode_cs)
 READ_STR:
      begin

   end
 READ_PAT:
      begin
  pat_index_cs<=pat_length-1;
  str_index_cs<=pat_length-1;
   end
    COMPARE_PAT:
       begin
          pat_index_cs<=pat_index_ns;
       str_index_cs<=str_index_ns;
       bm_cs<=bm_ns;
       shift_str_cs<=shift_str_ns;
       end    
  endcase
  end


always@(negedge clk or posedge reset)
  begin
    if(reset)
      count_str<=5'b0;
    else if(isstring)
      count_str<=count_str+5'b1;
 else if(mode_ns==STR_OR_PAT)
     count_str<=1'b0;
    else 
     count_str<=count_str;

  end
  
  always@(negedge clk)
  begin
 if(isstring)
      begin
  str_mem[count_str]<=chardata;
  str_length<=count_str;
   end
  end 
always@(negedge clk or posedge reset)
  begin
    if(reset)
      count_pat<=3'b0;
    else if (ispattern)
      count_pat<=count_pat+3'b1;
    else if(mode_ns==STR_OR_PAT)

     count_pat<=3'b0;
 else
       count_pat<=count_pat;
  end

always@(negedge clk)
  begin
 if(ispattern)
      begin
  pat_mem[count_pat]<=chardata;
  pat_length<=count_pat;
   end
  end 



  
  //Boyer-Moore combinational
always@(*)
if(reset)
begin
bm_ns=BM0;                
pat_index_ns=0;         
str_index_ns=0;
shift_str_ns=4'b0;
match_index=0;
end
else if(mode_cs==COMPARE_PAT)
  case(bm_cs)
    BM0:begin
      if(pat_mem[pat_index_cs]==str_mem[str_index_cs]||(pat_mem[pat_index_cs]==8'h2e))//str_index initial value is pat_length
     if(pat_index_cs==4'b0)         //p is zero
       begin
      bm_ns=BM2;                 //BM2 is success
      pat_index_ns=pat_index_cs;         
      str_index_ns=str_index_cs;
      shift_str_ns=4'b0;
      match_index=str_index_cs;
    end
     else
       begin
         bm_ns=BM0;                 
      pat_index_ns=pat_index_cs-1;
      str_index_ns=str_index_cs-1;
      shift_str_ns=shift_str_cs+1;
      match_index=str_index_cs;
       end   
   else
     begin
       bm_ns=BM1;
    pat_index_ns=pat_index_cs;
    str_index_ns=str_index_cs;
    shift_str_ns=shift_str_cs;
    match_index=str_index_cs;
     end
  end   
//BM1 is unmatching character
 BM1:begin
      if((pat_mem[pat_index_cs]==str_mem[str_index_cs])||(pat_mem[pat_index_cs]==8'h2e))
     begin
    if((str_index_cs+shift_str_cs)>str_length)
      begin
     bm_ns=BM3;  //BM3 is false
        str_index_ns=str_index_cs;
     pat_index_ns=pat_index_cs;
     shift_str_ns=0;
     match_index=str_index_cs;
      end
       else 
         begin
        bm_ns=BM0;
        str_index_ns=str_index_cs+shift_str_cs;
        pat_index_ns=pat_length;
     shift_str_ns=0;
     match_index=str_index_cs;
      end 
     end
      else
     begin
       if(pat_index_cs==4'b0)
     if((str_index_cs+shift_str_cs+1)>str_length)
        begin
       bm_ns=BM3;  //BM3 is false
          str_index_ns=str_index_cs;
       pat_index_ns=pat_index_cs;
       shift_str_ns=0;
       match_index=str_index_cs;
     end
      else 
        begin
          bm_ns=BM0;
          str_index_ns=str_index_cs+shift_str_cs+1;
       pat_index_ns=pat_length;
       shift_str_ns=0;
       match_index=str_index_cs;
        end 
    else 
      begin
        bm_ns=BM1;
        str_index_ns=str_index_cs;
     pat_index_ns=pat_index_cs-1;
     shift_str_ns=shift_str_cs+1;
     match_index=str_index_cs;
      end 
     end  
    end
   

//BM2 is match and valid    
 BM2:begin
  bm_ns=BM0;
  str_index_ns=str_index_cs;
  pat_index_ns=pat_index_cs;
  shift_str_ns=0;
  match_index=str_index_cs;
    end 
//BM3 is unmatch and valid 
 BM3:begin
  bm_ns=BM0;
  str_index_ns=str_index_cs;
  pat_index_ns=pat_index_cs;
  shift_str_ns=0;
  match_index=str_index_cs;
    end 
  endcase    
else
  begin
  bm_ns=BM0;
  str_index_ns=pat_length;
  pat_index_ns=pat_length;
  shift_str_ns=0;
 end 
 
  always@(negedge clk)
  begin
  if(mode_cs==COMPARE_PAT)
    if(reset)
   begin
      match<=1'b0;
   valid<=1'b0;
   //match_index<=0;
   end
    else if(bm_ns==BM2)
   begin
      match<=1'b1;
   valid<=1'b1;
      //match_index<=str_index_cs;
   end
 else if(bm_ns==BM3)
   begin
      match<=1'b0;
   valid<=1'b1;
      //match_index<=0;
   end
 else
   begin
      match<=1'b0;
   valid<=1'b0;
      //match_index<=0;
   end
  else
      begin
      match<=1'b0;
   valid<=1'b0;
      //match_index<=0;
   end
  end


endmodule
