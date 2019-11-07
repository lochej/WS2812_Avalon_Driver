module DynCntModN(Clk,Q,Mod,aSet,aReset);

parameter NBBITS=4;
parameter POSEDG=0;
parameter SETLEVEL=0;
parameter RESETLEVEL=0;
parameter UP_DOWN=1; //0 down 1 up

input Clk,aSet,aReset;
input [(NBBITS-1):0] Mod;
output[(NBBITS-1):0] Q;
reg[(NBBITS-1):0] Q;

wire _CLK,_Set,_Reset;

assign _CLK= (POSEDG) ? ~Clk:Clk;
assign _Set= (SETLEVEL) ? ~aSet : aSet;
assign _Reset=(RESETLEVEL) ? ~aReset:aReset;


always @(negedge(_CLK),negedge(_Set),negedge(_Reset))
begin

if(_Set==0)
begin
	Q<= (Mod-1);
end

else
begin

	if(_Reset==0)
	begin
		Q<={NBBITS{1'b0}};
	end
	
	else
	begin
	
		if(UP_DOWN==1)
		begin
			Q<= (Q+1)%Mod;
		end
		
		else
		begin
		
			if(Q==0)
			begin
				Q<=(Mod-1);
			end
			
			else
			begin
				Q<=(Q-1)%Mod;
			end
			
		end

	end
	
end




end

endmodule