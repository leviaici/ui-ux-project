//
//  RecentlyDeletedView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.09.2023.
//

import FirebaseFirestoreSwift
import SwiftUI
import UIKit

struct RecentlyDeletedView: View {
    @StateObject var viewModel: RecentlyDeletedViewViewModel
    @FirestoreQuery var items: [Item]
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText: String = ""

    init(userId: String) {
        self._items = FirestoreQuery(collectionPath: "users/\(userId)/todos")
        self._viewModel = StateObject(
            wrappedValue: RecentlyDeletedViewViewModel(userId: userId)
        )
    }
    
    var shownItems: [Item] {
        return items.filter { $0.recentlyDeleted == true }
    }
    
    var filteredShownItems: [Item] {
        if searchText.isEmpty {
            return shownItems
        } else {
            return shownItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack {
            if !shownItems.isEmpty {
                List {
                    SearchBar(text: $searchText)
                        .listRowSeparator(.hidden)
                    ForEach(filteredShownItems) { item in
                        showItems(item: item)
                    }
                    .listRowSeparator(.hidden)
                }
            } else {
                Text("There are no recently deleted items.")
                    .bold()
            }
        }
        .navigationTitle("Recently Deleted")
        .listStyle(PlainListStyle())
        .toolbar {
            if !shownItems.isEmpty {
                Button {
                    showAlert(outputText: "Delete All Items",
                              messageShown: "Are you sure you want to erase all these items?\nThis action cannot be reverted.",
                              viewModel: viewModel)
                } label: {
                    Text("Delete All")
                }.foregroundColor(.appColor)
            }
        }
    }


    func showItems(item: Item) -> some View {
        ItemView(item: item, showCheck: false)
            .swipeActions(edge: .trailing) {
                Button {
                    showAlert(outputText: "Delete Item",
                              messageShown: "Are you sure you want to erase this item?\nThis action cannot be reverted.",
                              viewModel: viewModel,
                              id: item.id)
                } label: {
                    Image(systemName: "trash.fill")
                }.tint(.red)
            }
            .swipeActions(edge: .leading) {
                Button {
                    viewModel.recover(id: item.id)
                } label: {
                    Image(systemName: "gobackward")
                }
                .tint(.appColor)
            }
                .listRowSeparator(.hidden)
    }
    
    func showAlert(outputText: String,
                   messageShown: String,
                   viewModel: RecentlyDeletedViewViewModel,
                   id: String = "") {
        
        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }

        let alert = UIAlertController(
            title: outputText + "?",
            message: messageShown,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: outputText,
            style: .destructive,
            handler: { _ in
                if(outputText == "Delete All Items") {
                    viewModel.deleteAllItems()
                    presentationMode.wrappedValue.dismiss()
                } else {
                    viewModel.delete(id: id)
                }
            }
        ))

        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: nil
        ))

        viewController.present(alert, animated: true, completion: nil)
    }
}

struct RecentlyDeleted_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyDeletedView(userId: "4GYnXVlMCMR8LQ0JErKq1OPRTeh2")
    }
}
