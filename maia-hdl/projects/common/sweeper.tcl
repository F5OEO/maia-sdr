###### SWEEPER ###########
	ad_disconnect  gpio_o sys_ps7/GPIO_O	


	create_bd_cell -type module -reference sweeper_it sweeper_io
	# Clock from the maia_sdr clock; end_fft is a data signal and is used as a step enable
	ad_connect sweeper_io/clk maia_sdr_clk/clk_out1
	ad_connect sweeper_io/step_in maia_sdr/clk_fastlock_out
	ad_connect sweeper_io/reset axi_ad9361/rst
	ad_connect sweeper_io/profile_o maia_sdr/fastlock_profile_in
	ad_ip_instance util_vector_logic logic_orgpio [list \
	  C_OPERATION {or} \
	  C_SIZE 64 ]

	create_bd_port -dir O -from 63 -to 0 gpio_o
	
	ad_connect sweeper_io/gpio_o logic_orgpio/Op1
	ad_connect sys_ps7/GPIO_O logic_orgpio/Op2
	ad_connect logic_orgpio/Res gpio_o