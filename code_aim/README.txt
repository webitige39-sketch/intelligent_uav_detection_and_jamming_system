cfar_condense_ila_no_gate_v8
============================

目的：
  先取消 narrow_candidate_gate，只验证 complex_abs -> CA-CFAR -> traces_condense。
  所有关键观测信号已经从 Freq_Thr -> DETECT_AIM -> MULT_FREQ_top 接到 AIM_ila_200M u_ila_200m。

替换/新增文件：
  1. FFT.v
     - 修复 m_axis_tuser_FFT 的符号扩展问题，改为零扩展：{6'b0, m_axis_tuser_1[9:0]}。

  2. traces_condense.v
     - 只做 CFAR hit 点迹凝聚。
     - 不做宽带/窄带判断。
     - 输出一个 candidate peak：峰值 bin + 峰值幅度。

  3. top_cfar.v
     - serial_cfar_2048 + traces_condense。
     - 增加 raw CFAR 和凝聚结果 debug 输出。
     - CFAR_PROT_LEN = 16, CFAR_REF_LEN = 32, CFAR_K = 6。

  4. Freq_Thr.v
     - 不再例化 narrow_candidate_gate。
     - F_user 直接来自 traces_condense 输出。
     - Freq_Thr_over 只有本帧存在 candidate 时才输出。
     - FIND_UAV 在本帧无 candidate 时输出。

  5. DETECT_AIM.v
     - 透传 Freq_Thr 内部 debug 信号。

  6. MULT_FREQ_top.v
     - 新增 debug wire。
     - DETECT_AIM_inst 增加 debug 端口连接。
     - AIM_ila_200M u_ila_200m 改为 20 个 probe。

AIM_ila_200M IP 需要重新 Customize：
  Number of Probes = 20
  Sample Data Depth 建议 8192
  Input Pipe Stages 建议 1

probe 位宽：
  probe0   1   DATA_LABEL
  probe1   1   WEA
  probe2   1   REA
  probe3   32  m_axis_tdata_ram
  probe4   32  m_axis_tdata_FFT
  probe5   1   m_axis_tvalid_FFT
  probe6   16  m_axis_tuser_FFT
  probe7   16  dbg_data_abs
  probe8   1   dbg_data_abs_valid
  probe9   1   dbg_data_abs_last
  probe10  32  {dbg_cfar_raw_idx, dbg_cfar_cut_amp}
  probe11  16  {13'd0, dbg_cfar_last, dbg_cfar_valid, dbg_cfar_hit}
  probe12  32  {dbg_condense_peak_idx, dbg_condense_peak_amp}
  probe13  16  {13'd0, dbg_condense_last, dbg_condense_valid, dbg_condense_hit}
  probe14  16  dbg_condense_user = {2'b0, target_id[3:0], peak_bin[9:0]}
  probe15  1   dbg_frame_has_candidate
  probe16  1   tr_m_axis_tvalid
  probe17  1   Freq_Thr_over_1
  probe18  16  F_user_200M
  probe19  1   FIND_UAV

当前 cross-trigger 方向保持原工程不变：
  AIM_ila_40M.trig_out -> AIM_ila_200M.trig_in

也就是说当前默认是 40MHz ILA 作为触发源，200MHz ILA 联动采集。
如果你想用 200MHz CFAR 事件作为主触发去触发 40MHz ILA，需要重新 Customize 两个 ILA：
  AIM_ila_200M 开启 trig_out/trig_out_ack
  AIM_ila_40M  开启 trig_in/trig_in_ack
然后在顶层把 trig 方向反过来。

建议触发：
  第一轮：用 40MHz ILA 触发 FIND 或 m_axis_tstart_thr，看 200MHz 侧整帧 CFAR 流程。
  第二轮：在 200MHz ILA 内部看 dbg_cfar_valid/dbg_condense_valid/Freq_Thr_over_1。

判读：
  1) CFAR 无 hit：
       dbg_cfar_valid 有连续数据，但 dbg_cfar_hit 始终 0。
       dbg_condense_valid = 0。
       Freq_Thr_over_1 = 0。
       FIND_UAV = 1。

  2) CFAR 有 hit，但凝聚没输出：
       看 dbg_cfar_raw_idx/cut_amp 和 dbg_cfar_hit 是否连续。
       检查 traces_condense 的 tlast 是否到来。

  3) 点迹凝聚正常：
       dbg_condense_valid 脉冲出现。
       dbg_condense_peak_idx 是候选峰 bin。
       dbg_condense_peak_amp 是候选峰幅度。
       dbg_condense_user[9:0] = dbg_condense_peak_idx[9:0]。

  4) F_user_200M：
       应等于 dbg_condense_user。
       F_user_200M[9:0] 是送给下级 DDS 的 FFT bin。
