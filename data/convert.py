import pandas as pd
import pickle

with open("character_genders.pickle", "rb") as f:
    data = pickle.load(f)

df = pd.DataFrame.from_dict(data, orient="index")
df.to_csv("character_genders.csv")
print("Fertig!")
