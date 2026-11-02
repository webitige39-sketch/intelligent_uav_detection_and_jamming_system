/*
    -------------------------------------------------------------------------------------------------
    
    说明： 并行输入的流水线单元平均型恒虚警检测模块。输入数据为包括待检测区域与保护区的全部数据，
           通过s_axis_tdata输入，并在s_axis_tvalid为高电平时标记有效。s_axis_tdata结构可以描述为
           ->[平均单元区域][保护单元区域][待检测单元][保护单元区域][平均单元区域]|
           模块将通过加法树计算平均单元区域内所有数据的和，并与一控制字k相乘作为参考数据，模块将
           待检测单元的数值与参考数据相比较，若待检测单元数值大于参考数据则输出高电平，且输出待检测
           单元的幅度。
           
    日志:  
        --------------------------------------------------------------------------------------------
        2018/12/18  [1].完成基础程序的编写
        --------------------------------------------------------------------------------------------
        2019/2/17   [2].该模块只需要完成恒虚警检测并输出结果，不需要进行距离单元标记，有效的单元标记
                        应该在顶层模块serial_cfar模块中实现。
        --------------------------------------------------------------------------------------------
      
    ------------------------------------------------------------------------------------------------
*/
module serial_cfar_pipeline
#(
	parameter DATA_WIDTH		=	16	,	//input data width
	parameter REF_UNIT_LENGTH	=	16	,	//reference unit length
	parameter PROT_UNIT_LENGTH	=	3	,	//protect unit length
	parameter CFAR_MODE			=	0	,	//the work mode of cfar
	parameter K_WIDTH			=	8		//multiply coefficient width
)
(
	s_axis_aclk	        ,
	s_axis_aresetn      ,
	s_axis_tdata		,
    s_axis_tvalid       ,
    s_axis_user_k		,
	m_axis_tdata	    ,
    m_axis_tvalid       ,
    m_axis_user_value           // 输出幅度值
);

/*
	FUNCTION DECLARATION
*/
	function integer blog2(input integer number)	;
		for(blog2=0;number>0;blog2=blog2+1)
			number=number>>1				;
	endfunction

/*
	PARAMETER DECLARATION
*/
	parameter DETECTED_PTR		=	REF_UNIT_LENGTH+PROT_UNIT_LENGTH+1	;	// pointer of detected unit
	parameter PARALLEL_NUM		=	DETECTED_PTR*2-1					;	// total unit number of tapped delay line		
	parameter PDATA_WIDTH		=	PARALLEL_NUM*DATA_WIDTH				;	// tapped delay line output parallel data width
	parameter LEVEL_NUM			=	blog2(REF_UNIT_LENGTH)-1			;	// level of add tree
	parameter ADD_TREE_WIDTH	=	DATA_WIDTH+LEVEL_NUM				;	// add tree result width
	parameter SUM_WIDTH			=	ADD_TREE_WIDTH+1					;	// sum of two add tree result
	parameter COMPARE_WIDTH		=	SUM_WIDTH+K_WIDTH					;	// width of multiply module result
	parameter COMPARE_DELAY		=	(LEVEL_NUM+3)			            ;	// the delay clock for compute the compare data
	
/*
	PORT DECLARATION
*/
	input 						   s_axis_aclk		                ;	
	input 						   s_axis_aresetn		            ;
	input 	[PDATA_WIDTH-1:0]	   s_axis_tdata		                ;	
    input                          s_axis_tvalid                    ;
    input 	[K_WIDTH-1:0]		   s_axis_user_k		            ;	//input 

	
	output						   m_axis_tdata	                    ;
    output                         m_axis_tvalid                    ;
    output  [DATA_WIDTH-1:0]       m_axis_user_value                ;
/*
	WIRE & REG DECLARATION
*/
	wire 	signed  [ADD_TREE_WIDTH-1:0]add_tree_left_dout	        ;	//left add tree result
	wire 	signed  [ADD_TREE_WIDTH-1:0]add_tree_right_dout	        ;	//right add tree result
	wire 	signed  [SUM_WIDTH-1:0]		add_tree_sum_dout	        ;	//sum of all add tree result
	wire 	signed  [COMPARE_WIDTH-1:0]	compare_value		        ;	//data used compare with detected_data
	wire 	signed  [DATA_WIDTH-1:0]	detected_data		        ;	
	wire 	signed  [DATA_WIDTH-1:0]	detected_data_delay	        ;	
	wire 						        cfar_result			        ;
	reg             [DATA_WIDTH-1:0]    m_axis_user_value           ;
    reg						            m_axis_tdata	                    ;
    reg                                 m_axis_tvalid                    ;
    // 待检测数据
	assign detected_data = s_axis_tdata[DETECTED_PTR*DATA_WIDTH-1-:DATA_WIDTH]	;

/*
	NOISE ESTIMATION
*/
    // 在待检测数据准备完成后计算结果
    
	//compute the sum of left reference unit
		add_tree#(
		.IS_BUFFERED 	(	1		)	,
		.DATA_WIDTH		(	DATA_WIDTH		)	,
		.ADD_NUM		(	REF_UNIT_LENGTH	)	
	)add_tree_inst_left(
		.clk	    (s_axis_aclk        ),
		.rst	    (~s_axis_aresetn    ),
		.din	    (s_axis_tdata[REF_UNIT_LENGTH*DATA_WIDTH-1:0]   ),
        .din_vld    (s_axis_tvalid      ),
		.dout	    (add_tree_left_dout ),
        .dout_vld   (add_tree_dout_vld  ));
	
	//compute the sum of right reference unit
	add_tree#(
		.IS_BUFFERED 	(	1		)	,
		.DATA_WIDTH		(	DATA_WIDTH		)	,
		.ADD_NUM		(	REF_UNIT_LENGTH	)	
	)add_tree_inst_right(
		.clk	    (s_axis_aclk            ),
		.rst	    (~s_axis_aresetn        ),
		.din	    (s_axis_tdata[PARALLEL_NUM*DATA_WIDTH-1-:REF_UNIT_LENGTH*DATA_WIDTH]),
		.din_vld    (s_axis_tvalid          ),
        .dout	    (add_tree_right_dout    ),
        .dout_vld   (                       ));
	
	//compute the sum of all reference unit
		add_module#(
		.IS_BUFFERED 	(1 	)	,
		.DATA_WIDTH		(ADD_TREE_WIDTH	)	,
        .IS_EN          (       1       )
	)sum_of_right_and_left(
		.clk		(s_axis_aclk		    )	,
		.rst		(~s_axis_aresetn	    )	,
		.din_a		(add_tree_left_dout	    )	,
		.din_b		(add_tree_right_dout    )	,
        .din_vld    (add_tree_dout_vld      )   ,
		.dout		(add_tree_sum_dout	    )	,
		.dout_vld	(add_tree_sum_dout_vld  )	);
	
/*
	COMPARE m_axis_user_value GENERATE
*/
    wire compare_value_vld;
	//multiply the sum of all reference data by k generate the compared m_axis_user_value
	multi_module#(
		.IS_BUFFERED 	(	1 		)	,
		.DATA_WIDTH_A	(	SUM_WIDTH			)	,
		.DATA_WIDTH_B 	(	K_WIDTH				)	
	)multi_module_inst0(
		.clk				(s_axis_aclk		    )	,
		.rst				(~s_axis_aresetn	    )	,
		.din_a				(add_tree_sum_dout      )	,
		.din_b				(s_axis_user_k			)	,
        .din_vld            (add_tree_sum_dout_vld  )   ,
		.dout				(compare_value		    )	,
		.dout_vld			(compare_value_vld      )	);
/*
	DELAY OF DETECTED UNIT
*/
	sync_module#(
			 .WIDTH			(	DATA_WIDTH 	        ),
			 .SYNC_TIME		(	COMPARE_DELAY		),
			 .IS_EN			(	 1'b0				)
		)delay_of_detected_unit(
			.clk			(	s_axis_aclk		    )	,
			.rst			(	~s_axis_aresetn		)	,
			.async_in		(   detected_data	    )	,
			.sync_out		(   detected_data_delay	)	,
			.parallel_out	(						)	,
			.en				(						));

/*
	OUTPUT COMPARE MODULE
*/
    // 求取均值
    wire signed[COMPARE_WIDTH-1:0]  compare_value_shift=compare_value>>>(LEVEL_NUM+1);  

	//compare the detected_data_delay with compare m_axis_user_value
	assign cfar_result=(detected_data_delay>compare_value_shift)?1'b1:1'b0;
	
	//register the cfar_result so that they can work at higher frequency
    always @ ( posedge s_axis_aclk )    
        if ( ~s_axis_aresetn )                      
            begin 
                m_axis_tdata     <= 0 ; 
                m_axis_tvalid    <= 0 ; 
                m_axis_user_value<= 0 ;
            end
        else if ( compare_value_vld )   
            begin  
                //m_axis_tdata     <= pipeline_fulldata_delay ? cfar_result : 0  ; 
                m_axis_tdata     <= cfar_result ; 
                m_axis_tvalid    <= 1 ; 
                // m_axis_user_value<= ( pipeline_fulldata_delay & cfar_result ) ? detected_data_delay : 0 ;
                m_axis_user_value<=  cfar_result? detected_data_delay : 0 ;
            end
        else                            
            begin 
                m_axis_tdata     <= 0 ; 
                m_axis_tvalid    <= 0 ; 
                m_axis_user_value<= 0 ;
            end
endmodule