format:
	python3 lua-format.py amen.lua
	python3 lua-format.py lib/amen.lua
	git commit -am "formatted"
	git diff HEAD^

download:
	wget https://raw.githubusercontent.com/schollz/LuaFormat/master/lua-format.py
