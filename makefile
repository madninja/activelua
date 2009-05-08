PLAT=macosx
INSTALL_TOP=/usr/local
CONFIG=config.$(PLAT)

include $(CONFIG)

DIR := .
export LUA_BASEPATH := $(shell lua -e 'print(package.path)' )
export LUA_PATH := $(DIR)/src/?.lua;$(DIR)/test/?.lua;$(LUA_BASEPATH)
LUA = lua

CORE_TO_SHAREDIR=\
	table_ext.lua\
	Class.lua\
	Object.lua\
	Array.lua\
	Base.lua\
	Associations.lua
	
STORE_TO_SHAREDIR=\
	SQL.lua\
	SQLite3.lua
	
all:

test:
	rm -f store.db
	$(LUA) test/test.lua

_SHAREBASE=$(LUA_SHAREDIR)/ActiveLua
	
install: all
	mkdir -p $(_SHAREBASE)
	cd src/ActiveLua; $(INSTALL_DATA) $(CORE_TO_SHAREDIR) $(_SHAREBASE)
	mkdir -p $(_SHAREBASE)/Store
	cd src/ActiveLua/Store; $(INSTALL_DATA) $(STORE_TO_SHAREDIR) $(_SHAREBASE)/Store
	
clean:
	rm -f store.db

path:
	$(LUA) -e "print(package.path)"
	
.PHONY : test install clean
