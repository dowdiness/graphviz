// Lexer implementation

///|
priv struct Lexer {
  input : String
  mut position : Int
  mut current_char : Char?
  mut token_start : Int
}

///|
fn Lexer::new(input : String) -> Lexer {
  let lexer = { input, position: 0, current_char: None, token_start: 0 }
  lexer.advance()
  lexer
}

///|
fn Lexer::current_index(self : Lexer) -> Int {
  match self.current_char {
    Some(_) => self.position - 1
    None => self.position
  }
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
      for ch = self.current_char {
        match ch {
          Some('\n') | None => break
          _ => {
            self.advance()
            continue self.current_char
          }
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
          for ch = self.current_char {
            match ch {
              Some('\n') | None => break
              _ => {
                self.advance()
                continue self.current_char
              }
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
          for ch = self.current_char {
            match ch {
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
  let buf = StringBuilder::new()
  for ch = self.current_char {
    match ch {
      Some(c) if c.is_numeric() || c.is_ascii_alphabetic() || c == '_' => {
        buf.write_char(c)
        self.advance()
        continue self.current_char
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_dotted_identifier(self : Lexer) -> String {
  self.advance()
  "." + self.read_identifier()
}

///|
fn Lexer::read_number(self : Lexer) -> String {
  let buf = StringBuilder::new()
  let mut has_dot = false
  for ch = self.current_char {
    match ch {
      Some(c) if c.is_numeric() => {
        buf.write_char(c)
        self.advance()
        continue self.current_char
      }
      Some('.') if !has_dot => {
        buf.write_char('.')
        has_dot = true
        self.advance()
        continue self.current_char
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_quoted_string(self : Lexer) -> String {
  let quote_char = self.current_char.unwrap()
  self.advance() // Skip opening quote
  let buf = StringBuilder::new()
  for ch = self.current_char {
    match ch {
      Some(c) if c == quote_char => break // End of string
      Some('\\') => {
        self.advance() // Skip escape character
        match self.current_char {
          Some(escaped_char) => {
            match escaped_char {
              'n' => buf.write_char('\n')
              't' => buf.write_char('\t')
              'r' => buf.write_char('\r')
              _ => buf.write_char(escaped_char)
            }
            self.advance()
            continue self.current_char
          }
          None => break // Unexpected end of input
        }
      }
      Some(c) => {
        buf.write_char(c)
        self.advance()
        continue self.current_char
      }
      None => break // End of input
    }
  }

  // Skip closing quote
  match self.current_char {
    Some(c) if c == quote_char => self.advance()
    _ => ()
  }
  buf.to_string()
}

///|
fn keyword_or_id(word : String) -> Token {
  let normalized = word.to_lower()
  match normalized {
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
      None => {
        self.token_start = self.position
        return EOF
      }
      Some('#') => {
        self.skip_comment() |> ignore
        continue
      }
      Some('/') => if self.skip_comment() { continue }
      _ => ()
    }
    self.token_start = self.current_index()
    match self.current_char {
      None => return EOF
      Some('/') => {
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
