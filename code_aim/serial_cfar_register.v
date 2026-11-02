/*
    -------------------------------------------------------------------------------------------------
    作者： 孙正源
    
    时间： 2019/1/31
    
    说明： 部分展开的串行恒虚模块影子寄存器模块
           
    日志:  
        --------------------------------------------------------------------------------------------
        2019/5/7    [1].用户反馈影子寄存器组里，高通道号所在的影子寄存器的编号低，输出会出现倒置现象
                        为解决此问题将
                        m_axis_tdata <= reg_bank[dout_num_cnt];
                        修改为
                        m_axis_tdata <= reg_bank[(PN-1)-dout_num_cnt];，这里是先输出高通道的数据
    ------------------------------------------------------------------------------------------------
*/
module serial_cfar_register
#(
    parameter DW = 16 ,// Data Width
    parameter PN = 1  ,// Parallel Number
    parameter WL = 49  // Window Length
)
(
	input                   s_axis_aclk    ,
    input                   s_axis_aresetn ,
    input [DW*PN-1:0]       s_axis_tdata   ,   // 并行输入数据，将一个多普勒通道的数据全部输出
    input                   s_axis_tvalid  ,
    
    output                  s_axis_tready  ,
    output reg [DW*WL-1:0]  m_axis_tdata   ,
    output reg              m_axis_tvalid   
);
/*
    REG & WIRE DECLARATION 
*/
    // 并行寄存器组,用于存储多组CFAR
 reg [DW*WL-1:0] reg_bank [PN-1:0] ;  
/*
    程序段名 ：输入缓存
    功能     ：在s_axis_tvalid信号有效时将s_axis_tdata并行的存入寄存器组中
    作者     ：孙正源
    创建日期 ：2019/1/31
    日志     ：
        2019/1/31 ：        寄存功能编写
                            1. generate语法有generate for, genreate if和generate case三种
                            2. generate for语句必须有genvar关键字定义for的变量
                            3. for 的内容必须加begin和end
                            4. 必须给for语段起个名字
                            仿真发现s_axis_tdata[(cnt+1)*DW-1-:DW]错误写成了s_axis_tdata[(cnt+1)*DW-1:0]
*/

    generate
        genvar cnt ;
        for ( cnt = 0 ; cnt < PN ; cnt = cnt + 1  )
            begin
                always @ ( posedge s_axis_aclk )
                if ( ~s_axis_aresetn)
                    reg_bank[cnt] <= 0 ;
                else if ( s_axis_tvalid )
                    reg_bank[cnt]<= {reg_bank[cnt][DW*(WL-1)-1:0],s_axis_tdata[(cnt+1)*DW-1-:DW]};
                else
                    reg_bank[cnt] <= reg_bank[cnt] ;
            end
    endgenerate
    
/*
    程序段名 ：寄存器组数据输出
    功能     ：在s_axis_tvalid有效后的下一个时钟周期启动数据输出操作，将会依次且连续输出PN个寄存器组数据
    作者     ：孙正源
    创建日期 ：2019/1/31
    日志     ：
        2019/1/31 ： 进行初期代码块编写
                     (*1)再功能编写时将默认最大并行数为256路，计数器采用8路，后期优化或扩展需要修改相关配置

*/

    // 输出数据计数器
    reg [7:0]dout_num_cnt ;/*(*1)*/
    // 输出完成信号，当输出计数达到PN或以上时代表数据已经输出完毕
    wire output_done = ( dout_num_cnt >= PN ) ;
    
    // 下文描述的计数器在每次输入有效时会将计数器清零，而计数器当数字小于PN时会不断自增
    // 直到其计数值达到PN,程序中其他逻辑会在计数值小于PN时控制数据的输出。
    always @ ( posedge s_axis_aclk )
        if ( ~s_axis_aresetn )
            dout_num_cnt <= PN ; 
        else if ( s_axis_tvalid )
            dout_num_cnt <= 0 ;
        else if ( ~output_done )
            dout_num_cnt <= dout_num_cnt + 1 ;
        else    
            dout_num_cnt <= dout_num_cnt ;

    // 输出数据的寄存,在未输出完成时，模块会将当前输出寄存器组寄存输出，并将有效信号置1
    always @ ( posedge s_axis_aclk )
        if ( ~s_axis_aresetn )
            begin
                m_axis_tdata <= 0 ;
                m_axis_tvalid<= 0 ;
            end
        else if ( ~output_done )
            begin
                m_axis_tdata <= reg_bank[(PN-1)-dout_num_cnt];
                m_axis_tvalid<= 1 ;
            end
        else
            begin
                m_axis_tdata <= 0 ;
                m_axis_tvalid<= 0 ;
            end
            
    
    // 在数据正在转换过程中，模块应该处于忙状态
    assign s_axis_tready = output_done ; 
    
endmodule