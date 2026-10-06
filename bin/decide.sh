# Structured decision: POST /v1/systemone — every question is evaluated in parallel and in
# isolation against the same state, and comes back typed. No text generation, nothing to parse.
# The answers{} map is keyed by your own question names; each answer holds its value under a
# key named after its type:
#   noul   -> { type, noul }                                      probability of "yes", 0..1
#   choice -> { type, choice, probabilities, confidence }          choice is one of your criteria keys
#   score  -> { type, score, legend, probabilities, confidence }   legend maps level index -> description
# usage carries input_tokens / output_tokens.
curl https://aihubmix.com/v1/systemone \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AIHUBMIX_API_KEY" \
  -d '{
    "model": "decision-model-preview",
    "state": "Hi, I have been trying to connect my Stripe account for 3 days and it keeps failing. I am losing sales. Please help ASAP.",
    "questions": {
      "department": {
        "type": "choice",
        "instructions": "Which team should handle this",
        "criteria": {
          "billing": "Payment or subscription issues",
          "technical": "Bugs or integration problems",
          "sales": "Pricing or account questions"
        }
      },
      "frustration": {
        "type": "score",
        "instructions": "How frustrated the customer appears",
        "criteria": [
          "Calm, just stating facts",
          "Frustrated but civil",
          "Very angry, strong language"
        ]
      },
      "is_urgent": {
        "type": "noul",
        "instructions": "The message conveys urgency or time-sensitivity"
      }
    }
  }'


# https://aihubmix.com/model/decision-model-preview
example code
