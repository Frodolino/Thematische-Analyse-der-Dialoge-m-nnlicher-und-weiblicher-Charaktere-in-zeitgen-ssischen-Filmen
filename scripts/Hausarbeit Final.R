library(reshape2)
library(tidyr)
library(dplyr)
library(stringr)
library(purrr)
library(tidytext)
library(topicmodels)
library(ggplot2)

# Gender-Daten einlesen und bereinigen
df_gender <- read.csv("data/character_genders.csv")

df_long <- df_gender %>%
  pivot_longer(cols = -X, names_to = "drop", values_to = "value") %>%
  filter(value != "") %>%
  mutate(
    name = str_extract(value, "(?<=\\().*?(?=',)"),
    gender = str_extract(value, "(?<=', ')[^']+(?='\\))"),
    name = str_remove(name, "^'")
  ) %>%
  select(imdb_id = X, name, gender) %>%
  filter(!is.na(name)) %>%
  distinct(imdb_id, name, .keep_all = TRUE)

# Metadaten einlesen und filtern
df_meta <- read.csv("data/movie_meta_data.csv")

df_long <- df_long %>% 
  filter(imdb_id %in% df_meta$imdbid)

# Dialogtexte einlesen
base_path <- "data/movie_character_texts/movie_character_texts"
movie_dirs <- list.files(base_path, full.names = TRUE)

get_imdb_id <- function(path) {
  as.integer(str_extract(basename(path), "(?<=_)\\d+$"))
}

df_texts <- map_dfr(movie_dirs, function(dir) {
  imdb_id <- get_imdb_id(dir)
  if (!imdb_id %in% df_long$imdb_id) return(NULL)
  map_dfr(list.files(dir, pattern = "\\.txt$", full.names = TRUE), function(f) {
    lines <- readLines(f, warn = FALSE)
    dialog_text <- str_extract(lines[str_detect(lines, "dialog:")], "(?<=dialog: ).*")
    tibble(imdb_id = imdb_id, name = str_remove(basename(f), "_text\\.txt$"), dialog = dialog_text)
  })
})

# Corpus erstellen
df_corpus <- df_texts %>%
  inner_join(df_long, by = c("imdb_id", "name")) %>%
  mutate(
    dialog = str_trim(str_remove_all(dialog, "\\([^)]*\\)")),
    dialog = str_remove_all(dialog, "(?i)script provided for educational purposes\\.?"),
    dialog = str_remove_all(dialog, "(?i)more scripts ca\\w*")
  ) %>%
  group_by(imdb_id, name, gender) %>%
  summarise(text = paste(dialog, collapse = " "), .groups = "drop") %>%
  filter(str_count(text, "\\w+") >= 30)

# Stopwörter
custom_stopwords <- tibble(word = c(
  # Regieanweisungen
  "takes", "pulls", "walks", "starts", "door", "eyes", "hand", "hands", "head",
  "looks", "turns", "moves", "stands", "sits", "gets", "goes", "come", "back",
  "smiles", "nods", "stares", "suddenly", "int", "ext", "cut", "fade", "stops",
  "holds", "watches", "steps", "makes", "smile", "front", "window", "moment",
  "beat", "inside", "close", "grabs", "reaches", "wall", "feet", "script",
  "hai", "floor", "table", "opens", "enters", "exits", "looks",
  # Eigennamen
  "jack", "john", "frank", "david", "harry", "charlie", "sam", "paul", "max",
  "joe", "peter", "george", "rachel", "anna", "aaron", "danny", "jacob", "lucy",
  "maggie", "hank", "lee", "thomas", "steve", "tom", "bruce", "ian", "kate",
  "sarah", "ben", "mary", "james", "henry", "norman", "billy", "nick", "amy",
  "jeff", "ted", "ed", "rose", "annie", "woody", "doug", "cole", "buzz",
  "diana", "william", "jim", "fred", "curtis", "eli", "jake", "bob", "eric",
  "walter", "louis", "kevin", "mike", "chris", "mark", "ryan", "matt", "scott",
  "adam", "alex", "carol", "oliver", "claire", "gary", "edward", "sally",
  "richard", "bobby", "audrey", "connie", "larry", "dave", "miles", "jamie",
  "carter", "lisa", "laura", "andrew", "wendy", "bill", "eddie", "johnny",
  "martin", "jay", "luke", "rebecca", "clark", "sara", "daniel", "craig", "ron",
  "tony", "andy", "tim", "rob", "ray"
))

# Tokenisieren
tidy_corpus <- df_corpus %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words, by = "word") %>%
  anti_join(custom_stopwords, by = "word") %>%
  filter(str_detect(word, "^[a-z]+$"))

# DTM erstellen
dtm <- tidy_corpus %>%
  count(imdb_id, name, word) %>%
  unite(doc_id, imdb_id, name, sep = "_") %>%
  cast_dtm(doc_id, word, n)

# Seltene Wörter und leere Dokumente entfernen
dtm_filtered <- dtm[, colSums(as.matrix(dtm) > 0) >= 5]
dtm_filtered <- dtm_filtered[rowSums(as.matrix(dtm_filtered)) > 0, ]

# LDA
lda_model <- LDA(dtm_filtered, k = 10, control = list(seed = 42))
terms(lda_model, 10)

# Topic-Zuordnung nach Gender
topic_assignments <- tidy(lda_model, matrix = "gamma") %>%
  separate(document, into = c("imdb_id", "name"), sep = "_", extra = "merge") %>%
  mutate(imdb_id = as.integer(imdb_id)) %>%
  left_join(df_corpus %>% select(imdb_id, name, gender), 
            by = c("imdb_id", "name")) %>%
  group_by(gender, topic) %>%
  summarise(mean_gamma = mean(gamma), .groups = "drop") %>%
  arrange(gender, desc(mean_gamma))

# Topic Labels
topic_labels <- c(
  "1" = "Familienleben/Zuhause",
  "2" = "Kriminalität/Gewalt",
  "3" = "Konflikt/Straßendialoge",
  "4" = "Militär/Abenteuer",
  "5" = "Familie/Emotionale Beziehungen",
  "6" = "Elternschaft/familiäre Fürsorge",
  "7" = "Nicht interpretierbar",
  "8" = "Business/Geldgeschäfte",
  "9" = "Alltag/Soziales Leben",
  "10" = "Kriminelle Geschäfte/Überfall"
)

# Plot 1: Alle Topics nach Gender
topic_assignments %>%
  filter(!topic %in% c(4, 7)) %>%
  mutate(
    topic = factor(topic_labels[as.character(topic)], levels = topic_labels),
    gender = factor(recode(gender, 
                           "actor" = "Männliche Charaktere", 
                           "actress" = "Weibliche Charaktere"),
                    levels = c("Männliche Charaktere", "Weibliche Charaktere"))
  ) %>%
  ggplot(aes(x = topic, y = mean_gamma, fill = gender)) +
  geom_bar(stat = "identity", position = "dodge") +
  coord_flip() +
  labs(title = "Durchschnittliche Themen-Verteilung nach Gender",
       x = "Thema", y = "Themenanteil",
       fill = "Gender") +
  guides(fill = guide_legend(reverse = TRUE)) +
  theme_minimal()

# Werte Plot 1: Alle Topics nach Gender
topic_assignments %>%
  filter(!topic %in% c(4, 7)) %>%
  arrange(topic, gender)


# Plot 2: Gruppierte Topics nach Gender
topic_assignments %>%
  filter(topic %in% c(1, 2, 3, 5, 6, 10)) %>%
  mutate(
    gruppe = case_when(
      topic %in% c(1, 5, 6) ~ "Familie",
      topic %in% c(2, 3, 10) ~ "Gewalt/Kriminalität/Konflikt"
    ),
    gender = factor(recode(gender,
                           "actor" = "Männliche Charaktere",
                           "actress" = "Weibliche Charaktere"),
                    levels = c("Männliche Charaktere", "Weibliche Charaktere"))
  ) %>%
  group_by(gruppe, gender) %>%
  summarise(sum_gamma = sum(mean_gamma), .groups = "drop") %>%
  ggplot(aes(x = gruppe, y = sum_gamma, fill = gender)) +
  geom_bar(stat = "identity", position = "dodge") +
  coord_flip() +
  labs(title = "Themenverteilung nach Gruppe und Gender",
       x = "Themengruppe", y = "Summe Themenanteile",
       fill = "Gender") +
  guides(fill = guide_legend(reverse = TRUE)) +
  theme_minimal()

# Werte Plot 2: Gruppierte Topics nach Gender
topic_assignments %>%
  filter(topic %in% c(1, 2, 3, 5, 6, 10)) %>%
  mutate(
    gruppe = case_when(
      topic %in% c(1, 5, 6) ~ "Familie",
      topic %in% c(2, 3, 10) ~ "Gewalt/Kriminalität/Konflikt"
    )
  ) %>%
  group_by(gruppe, gender) %>%
  summarise(sum_gamma = sum(mean_gamma), .groups = "drop")
