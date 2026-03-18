'data' DIRECTORY FILES DESCRIPTION

1. movie_character_texts.zip:
Archive structure:
	movie_character_texts/
		<movie_0_name>_<movie_0_imdb_id>/
			<movie_0_character_0_name>_text.txt
			<movie_0_character_1_name>_text.txt
			...
		<movie_1_name>_<movie_1_imdb_id>/
			<movie_1_character_0_name>_text.txt
			<movie_1_character_1_name>_text.txt
			...
		...

Data description:
	Each TXT-file consists of textual data of following type:
		<i_0>)<k_0>) <label>: <data>
		<i_0>)<k_1>) <label>: <data>
		...
		<i_1>)<k_0>) <label>: <data>
		<i_1>)<k_1>) <label>: <data>	
		...
	Where i - number of screenplay segment and k - number of screenplay scene, where character is involved.
	Segments and scenes are used while annotating with rule-based annotator (from https://github.com/drwiner/ScreenPy).
	<label> can be 'dialog' or 'text', <data> - text row from original screenplay

2. character_genders.pickle:
Data description:
	A dictionary of following type:
		root : {}
			 <movie_0_imdb_id>: []
						0: []
							<movie_0_character_0_name>
							<movie_0_character_0_type>
						1: []
							<movie_0_character_1_name>
							<movie_0_character_1_type>
						...
			  <movie_1_imdb_id>: []
						0: []
							<movie_1_character_0_name>
							<movie_1_character_0_type>
						1: []
							<movie_1_character_1_name>
							<movie_1_character_1_type>
						...		
			  ...

 	Where character type can be 'actor' or 'actress'