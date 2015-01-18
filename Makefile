UGLIFY := ./node_modules/.bin/uglifyjs --comments "/^!/"
COFFEE := ./node_modules/.bin/coffee -p

all:
	$(COFFEE) toyger.coffee | $(UGLIFY) > dist/toyger.min.js
	cat node_modules/kramed/kramed.min.js >> dist/toyger.min.js

.PHONY: all
