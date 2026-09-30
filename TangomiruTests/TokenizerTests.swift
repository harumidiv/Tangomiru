import Foundation
import Testing
@testable import Tangomiru

struct TokenizerTests {
    let tokenizer = Tokenizer()

    private func token(_ surface: String, in result: TokenizedText) -> Token? {
        result.tokens.first { $0.surface == surface }
    }

    @Test func lemmatizesInflectedWords() {
        let result = tokenizer.tokenize("She was running and the children ate apples.")
        #expect(token("running", in: result)?.lemma == "run")
        #expect(token("children", in: result)?.lemma == "child")
        #expect(token("ate", in: result)?.lemma == "eat")
        #expect(token("She", in: result)?.lemma == "she")
    }

    @Test func marksProperNouns() {
        let result = tokenizer.tokenize("I met John Smith in Tokyo yesterday.")
        #expect(token("Tokyo", in: result)?.isProperNoun == true)
        #expect(token("Smith", in: result)?.isProperNoun == true)
        #expect(token("met", in: result)?.isProperNoun == false)
    }

    @Test func spansPointToSurfaceInUTF16() {
        let text = "😀 “Café” is ubiquitous."
        let result = tokenizer.tokenize(text)
        let ns = text as NSString
        #expect(!result.tokens.isEmpty)
        for token in result.tokens {
            #expect(ns.substring(with: NSRange(location: token.span.location, length: token.span.length)) == token.surface)
        }
        #expect(token("ubiquitous", in: result)?.span.location == 13)
    }

    @Test func assignsSentenceIndexes() {
        let result = tokenizer.tokenize("I like cats. Dogs are loyal.")
        #expect(result.sentences == ["I like cats.", "Dogs are loyal."])
        #expect(token("cats", in: result)?.sentenceIndex == 0)
        #expect(token("Dogs", in: result)?.sentenceIndex == 1)
    }

    @Test func tracksPunctuationBetweenTokens() {
        #expect(token("cream", in: tokenizer.tokenize("ice cream"))?.followsPreviousDirectly == true)
        #expect(token("cream", in: tokenizer.tokenize("ice, cream"))?.followsPreviousDirectly == false)
        #expect(tokenizer.tokenize("ice cream").tokens.first?.followsPreviousDirectly == false)
    }

    @Test func tagsPartOfSpeech() {
        let result = tokenizer.tokenize("She runs every day. It was a beautiful run.")
        #expect(token("runs", in: result)?.partOfSpeech == .verb)
        #expect(token("run", in: result)?.partOfSpeech == .noun)
        #expect(token("beautiful", in: result)?.partOfSpeech == .adjective)
    }

    @Test func omitsPunctuationAndWhitespace() {
        let result = tokenizer.tokenize("Hello, world!")
        #expect(result.tokens.map(\.surface) == ["Hello", "world"])
    }
}
