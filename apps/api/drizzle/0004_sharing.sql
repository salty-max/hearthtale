CREATE TABLE "shares" (
	"token" text PRIMARY KEY NOT NULL,
	"character_id" integer NOT NULL,
	"part" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "characters" ADD COLUMN "in_hall" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "shares" ADD CONSTRAINT "shares_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "shares_character" ON "shares" USING btree ("character_id");