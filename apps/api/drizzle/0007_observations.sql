CREATE TABLE "observations" (
	"id" serial PRIMARY KEY NOT NULL,
	"game" text NOT NULL,
	"locale" text NOT NULL,
	"kind" text NOT NULL,
	"entity" text NOT NULL,
	"field" text NOT NULL,
	"value" text NOT NULL,
	"value_hash" text NOT NULL,
	"build" text,
	"contributors" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"first_seen" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX "observations_fact" ON "observations" USING btree ("game","locale","kind","entity","field","value_hash");--> statement-breakpoint
CREATE INDEX "observations_seen" ON "observations" USING btree ("last_seen");