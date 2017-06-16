require 'sinatra'
require "sinatra/json"
require "google/cloud/language"

set :bind, '0.0.0.0'

project_id = "fifth-audio-170817"
language = Google::Cloud::Language.new project: project_id

class RequestHandler
    def can_handle?(document)
        true
    end

    def handle(document)
        { "type" => "UNKNOWN", "details" => {} }
    end
end

class SearchRequestHandler < RequestHandler

    def initialize(search_type, subject_name)
        @search_type = search_type
        @subject_name = subject_name
    end

    def can_handle?(document)
        document.entities.any? { |e| e.name == @subject_name }
    end

    def handle(document)
        tokens = document.syntax.tokens
        subject_index = tokens.index(tokens.find { |t| t.text == @subject_name})
        descriptive_labels = ["ACOMP", "AMOD", "ADVMOD", "ADVCL", "POBJ"]

        search_terms = tokens.select { |t| descriptive_labels.include?(t.label.to_s) }
                             .select { |t| eventually_points_to?(tokens, tokens.index(t), subject_index)}
                             .map { |t| t.text }
                             .join(" ")

        { "type" => @search_type, "details" => { "searchQuery" => search_terms } }
    end

    def eventually_points_to?(tokens, token_index, term_index, terms_visited=[])
        terms_visited << token_index

        if (tokens[token_index].head_token_index == term_index)
            return true
        elsif (terms_visited.include?(tokens[token_index].head_token_index))
            return false
        end
        
        return eventually_points_to?(tokens, tokens[token_index].head_token_index, term_index, terms_visited)
    end
end

class OrderSearchRequestHandler < SearchRequestHandler
    def initialize()
        super("ORDER_SEARCH", "orders")
    end 
end

class ProductSearchRequestHandler < SearchRequestHandler
    def initialize()
        super("PRODUCT_SEARCH", "products")
    end 
end

handlers = [OrderSearchRequestHandler.new, ProductSearchRequestHandler.new, RequestHandler.new]

get '/' do 
    request = params[:request]
    doc = language.document(request)
    json handlers.select { |h| h.can_handle?(doc)}
                 .first
                 .handle(doc)
end