test_function <- function(x) {
  
  result <- x^2 + 10*x 
  return(result)
}
test_function(seq(-10,10))
plot(test_function(seq(-10,10)), type ="l")

rattenVector <- c(1,2,3,4,5,6,7,8,9)
rabenVector <- 1:3
rattenVector == rabenVector
names(rabenVector) <- c("a", "b", "a")
print(rabenVector)
print(rabenVector["a"])
rabenVector[names(rabenVector) == "a"]
