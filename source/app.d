import vibe.d;

shared static this()
{
	auto router = new URLRouter;
	router.get("/", staticTemplate!"create.dt");
	router.get("/created", &createNote);
	router.post("/created", &createNote);
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];

	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

void createNote(HTTPServerRequest req, HTTPServerResponse res)
{
	if (req.method != HTTPMethod.GET && req.method != HTTPMethod.POST) return;

	auto formdata = (req.method == HTTPMethod.GET ? &req.query : &req.form);

	string topic = formdata.get("form_topic");
	string content = formdata.get("form_content");

	string reqmethod = httpMethodString(req.method);
	render!("created.dt", topic, content, reqmethod)(res);
}
