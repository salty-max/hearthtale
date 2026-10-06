CREATE TABLE "characters" (
	"id" serial PRIMARY KEY NOT NULL,
	"guid" text NOT NULL,
	"name" text NOT NULL,
	"realm" text,
	"region" integer,
	"race" text NOT NULL,
	"class" text NOT NULL,
	"client" text NOT NULL,
	"level" integer NOT NULL,
	"hardcore" boolean DEFAULT false NOT NULL,
	"fallen" boolean DEFAULT false NOT NULL,
	"book" jsonb NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "characters_guid_unique" UNIQUE("guid")
);
