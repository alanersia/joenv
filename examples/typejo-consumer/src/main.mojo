from typejo import Constraints, PrimitiveValue, validate

def main() raises:
    var username = PrimitiveValue(String("Mira"))
    var rules = Constraints(min_length=3, max_length=12)
    var valid = validate[String](username, rules)
    if not valid.is_ok():
        raise Error("valid username was rejected")
    print("Valid username:", valid.value())

    var short_username = PrimitiveValue(String("Jo"))
    var invalid = validate[String](short_username, rules)
    if invalid.is_ok() or invalid.issues()[0].code != "too_short":
        raise Error("short username should fail validation")
    print("Invalid username:", invalid.issues()[0].code)
