# frozen_string_literal: true

require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    !list_new?(list) && todos_remaining(list) == 0
  end

  def list_new?(list)
    list[:todos].empty?
  end

  def todos_remaining(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def list_class(list)
    if list_complete?(list)
      "complete"
    elsif list_new?(list)
      "new"
    end
  end

  def sort_lists(lists, &block)
    complete, incomplete = lists.partition { |list| list_complete?(list) }

    incomplete.each { |list| yield list, lists.index(list) }
    complete.each { |list| yield list, lists.index(last)}
  end

  def sort_todos(todos, &block)
    complete, incomplete = todos.partition { |todo| todo[:completed] }

    incomplete.each { |todo| yield todo, todos.index(todo) }
    complete.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid, returns nil otherwise
def error_for_list_name(name)
  if !(1..50).cover? name.size
    'List name must be between 1 and 50 characters!'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique!'
  end
end

def error_for_todo(name)
  if !(1..100).cover? name.size
    'Todo name must be between 1 and 100 characters!'  
  end  
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# view single list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do  
  id = params[:id].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error    
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    redirect "/lists/#{id}"
  end
end

post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# adding a new todo to a list
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added!"
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from the list
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at todo_id
  session[:success] = "The todo has been deleted!"
  redirect "/lists/#{@list_id}"
end

# check off/complete a todo off the list
post "/lists/:list_id/todos/:todo_id" do  
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated!"
  redirect "/lists/#{@list_id}"
end
# mark all todos as complete for the list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed!"
  redirect "/lists/#{@list_id}"
end

helpers do
  def list_complete?(list)
    list[:todos].all? { |todo| todo[:completed] == true } &&
    list[:todos].size >= 1
  end

  def count_completed_todos(list)
    list[:todos].count { |todo| todo[:completed] == true }
  end
end