SERVERSRC = server/db.coffee server/config.coffee server/server.coffee server/avalon.coffee
SERVER = avalon.js

CLIENTSRC = server/config.coffee client/client.coffee
CLIENT = js/avalon.js

STATSSRC = client/stats.coffee
STATS = js/stats.js

.PHONY: all
all: $(SERVER) $(CLIENT) $(STATS)

$(STATS): $(STATSSRC)
	coffee -j $(STATS) -c $(STATSSRC)

$(CLIENT): $(CLIENTSRC)
	coffee -j $(CLIENT) -c $(CLIENTSRC)

$(SERVER): $(SERVERSRC)
	coffee -j $(SERVER) -c $(SERVERSRC)

clean:
	rm -rf $(CLIENT) $(SERVER)

