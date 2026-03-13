// Lexer implementation

///|
priv struct Lexer {
  input : String
  mut position : Int
  mut current_char : Char?
}

///|
fn Lexer::new(input : String) -> Lexer {
  let lexer = { input, position: 0, current_char: None }
  lexer.advance()
  lexer
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  if self.position >= self.input.length() {
    self.current_char = None
  } else {
    match UInt16::to_char(self.input.at(self.position)) {
      Some(ch) => self.current_char = Some(ch)
      None => self.current_char = None
    }
    self.position += 1
  }
}

///|
fn Lexer::peek_char(self : Lexer) -> Char? {
  if self.position >= self.input.length() {
    None
  } else {
    UInt16::to_char(self.input.at(self.position))
  }
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  match self.current_char {
    Some(' ') | Some('\t') | Some('\n') | Some('\r') => {
      self.advance()
      self.skip_whitespace()
    }
    _ => ()
  }
}

///|
fn Lexer::skip_comment(self : Lexer) -> Bool {
  match self.current_char {
    Some('#') => {
      // Hash comment: consume until newline or EOF
      loop self.current_char {
        Some('\n') | None => break
        _ => {
          self.advance()
          continue self.current_char
        }
      }
      true
    }
    Some('/') =>
      match self.peek_char() {
        Some('/') => {
          // Consume both slashes
          self.advance()
          self.advance()
          // Single line comment
          loop self.current_char {
            Some('\n') | None => break
            _ => {
              self.advance()
              continue self.current_char
            }
          }
          true
        }
        Some('*') => {
          // Consume '/' and '*'
          self.advance()
          self.advance()
          let mut closed = false
          // Multi-line comment
          loop self.current_char {
            None => break
            Some('*') => {
              self.advance()
              match self.current_char {
                Some('/') => {
                  self.advance()
                  closed = true
                  break
                }
                _ => continue self.current_char
              }
            }
            _ => {
              self.advance()
              continue self.current_char
            }
          }
          closed
        }
        _ => false
      }
    _ => false
  }
}

///|
fn Lexer::read_identifier(self : Lexer) -> String {
  loop (self.current_char, "") {
    (Some(c), acc) if c.is_numeric() || c.is_ascii_alphabetic() || c == '_' => {
      self.advance()
      continue (self.current_char, acc + c.to_string())
    }
    (_, acc) => break acc
  }
}

///|
fn Lexer::read_dotted_identifier(self : Lexer) -> String {
  self.advance()
  "." + self.read_identifier()
}

///|
fn Lexer::read_number(self : Lexer) -> String {
  loop (self.current_char, "", false, false) {
    (Some(c), acc, has_dot, _) if c.is_numeric() => {
      self.advance()
      continue (self.current_char, acc + c.to_string(), has_dot, true)
    }
    (Some('.'), acc, false, has_digit) => {
      self.advance()
      continue (self.current_char, acc + ".", true, has_digit)
    }
    (_, acc, _, _) => break acc
  }
}

///|
fn Lexer::read_quoted_string(self : Lexer) -> String {
  let quote_char = self.current_char.unwrap()
  self.advance() // Skip opening quote
  let result = loop (self.current_char, "") {
    (Some(c), acc) if c == quote_char => break acc // End of string
    (Some('\\'), acc) => {
      self.advance() // Skip escape character
      match self.current_char {
        Some(escaped_char) => {
          self.advance()
          continue (self.current_char, acc + escaped_char.to_string())
        }
        None => break acc // Unexpected end of input
      }
    }
    (Some(c), acc) => {
      self.advance()
      continue (self.current_char, acc + c.to_string())
    }
    (None, acc) => break acc // End of input
  }

  // Skip closing quote
  match self.current_char {
    Some(c) if c == quote_char => self.advance()
    _ => ()
  }
  result
}

///|
fn keyword_or_id(word : String) -> Token {
  match word {
    "strict" => Strict
    "graph" => Graph
    "digraph" => Digraph
    "node" => Node
    "edge" => Edge
    "subgraph" => Subgraph
    _ => ID(word)
  }
}

///|
fn Lexer::next_token(self : Lexer) -> Token {
  while true {
    self.skip_whitespace()
    match self.current_char {
      None => return EOF
      Some('#') => self.skip_comment() |> ignore
      Some('/') => {
        if self.skip_comment() {
          continue
        }
        self.advance()
        return ID("/")
      }
      Some('{') => {
        self.advance()
        return LeftBrace
      }
      Some('}') => {
        self.advance()
        return RightBrace
      }
      Some('[') => {
        self.advance()
        return LeftBracket
      }
      Some(']') => {
        self.advance()
        return RightBracket
      }
      Some(':') => {
        self.advance()
        return Colon
      }
      Some(';') => {
        self.advance()
        return Semicolon
      }
      Some(',') => {
        self.advance()
        return Comma
      }
      Some('=') => {
        self.advance()
        return Equals
      }
      Some('-') => {
        self.advance()
        match self.current_char {
          Some('-') => {
            self.advance()
            return Line
          }
          Some('>') => {
            self.advance()
            return Arrow
          }
          _ => return ID("-")
        }
      }
      Some('"') | Some('\'') => {
        let str = self.read_quoted_string()
        return ID(str)
      }
      Some(c) if c.is_ascii_alphabetic() || c == '_' => {
        let word = self.read_identifier()
        return keyword_or_id(word)
      }
      Some(c) if c.is_numeric() => {
        let word = self.read_number()
        return ID(word)
      }
      Some('.') =>
        match self.peek_char() {
          Some(next) if next.is_numeric() => {
            let word = self.read_number()
            return ID(word)
          }
          Some(next) if next.is_ascii_alphabetic() || next == '_' => {
            let word = self.read_dotted_identifier()
            return ID(word)
          }
          _ => {
            self.advance()
            return ID(".")
          }
        }
      Some(c) => {
        self.advance()
        return ID(c.to_string())
      }
    }
  }
  EOF
}
