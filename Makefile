SERVERSRC = server/db.coffee server/config.coffee server/server.coffee server/avalon.coffee
SERVER = avalon.js

CLIENTSRC = server/config.coffee client/client.coffee
CLIENT = js/avalon.js

STATSSRC = client/stats.coffee
STATS = js/stats.js

ADMINSRC = client/admin.coffee
ADMIN = js/admin.js

.PHONY: all
all: $(SERVER) $(CLIENT) $(STATS) $(ADMIN)

$(STATS): $(STATSSRC)
	coffee -j $(STATS) -c $(STATSSRC)

$(ADMIN): $(ADMINSRC)
	coffee -j $(ADMIN) -c $(ADMINSRC)

$(CLIENT): $(CLIENTSRC)
	coffee -j $(CLIENT) -c $(CLIENTSRC)

$(SERVER): $(SERVERSRC)
	coffee -j $(SERVER) -c $(SERVERSRC)

clean:
	rm -rf $(CLIENT) $(SERVER)

