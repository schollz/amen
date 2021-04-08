format: lua-format.py
	python3 lua-format.py amen.lua
	python3 lua-format.py lib/amen.lua
# 	git commit -am "formatted"
# 	git diff HEAD^

lua-format.py:
	wget https://raw.githubusercontent.com/schollz/LuaFormat/master/lua-format.py
